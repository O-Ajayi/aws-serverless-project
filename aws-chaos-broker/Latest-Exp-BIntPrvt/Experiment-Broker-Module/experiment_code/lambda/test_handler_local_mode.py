"""
Test suite for handler local_mode functionality.

This test file validates that the handler correctly handles local_mode:
- Loads experiments from local filesystem instead of S3
- Skips DynamoDB writes in local mode
- Skips S3 and OpenSearch uploads in local mode
- Handles relative and absolute paths correctly
- Properly handles success/failure states

To run these tests:
    python -m unittest test_handler_local_mode
    # or
    python -m unittest test_handler_local_mode.TestHandlerLocalMode.test_local_mode_loads_from_file_system

Prerequisites:
    - All dependencies from requirements.txt must be installed
    - Tests use mocking, so no actual AWS credentials needed
"""
import unittest
import os
import json
import tempfile
from unittest.mock import Mock, patch, MagicMock, mock_open
from dataclasses import dataclass

from handler import handler


@dataclass
class MockContext:
    function_name: str = "test"
    aws_request_id: str = "88888888-4444-4444-4444-121212121212"
    invoked_function_arn: str = "arn:aws:lambda:eu-west-1:123456789101:function:test"


class TestHandlerLocalMode(unittest.TestCase):
    """Test handler with local_mode enabled"""

    def setUp(self):
        """Set up test fixtures"""
        # Create a temporary experiment YAML file
        self.temp_dir = tempfile.mkdtemp()
        self.test_experiment_path = os.path.join(self.temp_dir, "test_experiment.yml")
        
        # Create a simple test experiment YAML
        test_experiment_content = """
version: 1.0.0
title: Test Experiment
description: A test experiment for local mode
configuration:
  aws_region: us-east-1
method:
  - type: probe
    name: test-probe
    provider:
      type: python
      module: experimentvr.ec2.probes
      func: instance_healthy
      arguments:
        region: ${aws_region}
"""
        with open(self.test_experiment_path, 'w') as f:
            f.write(test_experiment_content)

        # Mock experiment journal result
        self.mock_journal = {
            "status": "completed",
            "deviated": False,
            "steady_state_hypothesis": {"status": "probe"},
            "experiment": {"title": "Test Experiment"},
        }

    def tearDown(self):
        """Clean up test fixtures"""
        if os.path.exists(self.test_experiment_path):
            os.remove(self.test_experiment_path)
        if os.path.exists(self.temp_dir):
            os.rmdir(self.temp_dir)

    @patch('handler.boto3')
    @patch('handler.upload_experiment_journal')
    @patch('handler.put_object')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_loads_from_file_system(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_put_object,
        mock_upload_journal,
        mock_boto3
    ):
        """Test that local_mode loads experiment from file system instead of S3"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal

        # Create event with local_mode enabled
        event = {
            "local_mode": True,
            "experiment_source": self.test_experiment_path,
            "configuration": {"aws_region": "us-east-1"},
        }

        # Call handler
        result = handler(event, MockContext())

        # Assertions
        # Should load from file system, not S3
        mock_load_experiment.assert_called_once_with(self.test_experiment_path)
        mock_run_experiment.assert_called_once_with(mock_experiment)
        
        # Should NOT call S3 functions
        mock_boto3.Session.assert_not_called()
        
        # Should NOT upload to external services
        mock_put_object.assert_not_called()
        mock_upload_journal.assert_not_called()
        
        # Should update state to done
        self.assertEqual(result["state"], "done")
        self.assertIn("response", result)
        self.assertIn("report_capture", result)

    @patch('handler.boto3')
    @patch('handler.upload_experiment_journal')
    @patch('handler.put_object')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_with_relative_path(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_put_object,
        mock_upload_journal,
        mock_boto3
    ):
        """Test that local_mode resolves relative paths correctly"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal

        # Change to temp directory and use relative path
        original_cwd = os.getcwd()
        try:
            os.chdir(self.temp_dir)
            relative_path = "test_experiment.yml"
            
            event = {
                "local_mode": True,
                "experiment_source": relative_path,
                "configuration": {"aws_region": "us-east-1"},
            }

            result = handler(event, MockContext())

            # Should resolve to absolute path
            expected_abs_path = os.path.abspath(relative_path)
            mock_load_experiment.assert_called_once()
            call_args = mock_load_experiment.call_args[0][0]
            self.assertTrue(os.path.isabs(call_args))
            
            # Should update state
            self.assertEqual(result["state"], "done")
        finally:
            os.chdir(original_cwd)

    @patch('handler.configure_logger')
    def test_local_mode_file_not_found(self, mock_configure_logger):
        """Test that local_mode raises FileNotFoundError when file doesn't exist"""
        event = {
            "local_mode": True,
            "experiment_source": "/nonexistent/path/experiment.yml",
            "configuration": {"aws_region": "us-east-1"},
        }

        with self.assertRaises(FileNotFoundError) as context:
            handler(event, MockContext())

        self.assertIn("Experiment file not found", str(context.exception))

    @patch('handler.boto3')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_skips_dynamodb(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_boto3
    ):
        """Test that local_mode skips DynamoDB writes"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal

        event = {
            "local_mode": True,
            "experiment_source": self.test_experiment_path,
            "configuration": {"aws_region": "us-east-1"},
        }

        result = handler(event, MockContext())

        # Should NOT create DynamoDB session
        mock_boto3.Session.assert_not_called()

    @patch('handler.boto3')
    @patch('handler.upload_experiment_journal')
    @patch('handler.put_object')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.get_object')
    @patch('handler.create_presigned_url')
    @patch('handler.configure_logger')
    def test_normal_mode_uses_s3(
        self,
        mock_configure_logger,
        mock_create_presigned_url,
        mock_get_object,
        mock_load_experiment,
        mock_run_experiment,
        mock_put_object,
        mock_upload_journal,
        mock_boto3
    ):
        """Test that normal mode (not local_mode) uses S3"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal
        mock_create_presigned_url.return_value = "https://s3.amazonaws.com/bucket/file.yml"

        event = {
            "local_mode": False,  # Explicitly set to False
            "experiment_source": "experiments/test.yml",
            "bucket_name": "test-bucket",
            "output_config": {
                "S3": {
                    "bucket_name": "output-bucket",
                    "path": "journals/",
                },
                "OPENSEARCH": {
                    "index": "test-index",
                    "host": "test-host",
                },
            },
        }

        result = handler(event, MockContext())

        # Should call S3 functions
        mock_get_object.assert_called_once()
        mock_create_presigned_url.assert_called_once_with("test-bucket", "experiments/test.yml")
        mock_load_experiment.assert_called_once_with("https://s3.amazonaws.com/bucket/file.yml")

    @patch('handler.boto3')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_failed_experiment(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_boto3
    ):
        """Test that local_mode correctly handles failed experiments"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        
        # Mock failed experiment
        failed_journal = {
            "status": "failed",
            "deviated": True,
            "steady_state_hypothesis": {"status": "deviated"},
        }
        mock_run_experiment.return_value = failed_journal

        event = {
            "local_mode": True,
            "experiment_source": self.test_experiment_path,
            "configuration": {"aws_region": "us-east-1"},
        }

        result = handler(event, MockContext())

        # Should update state to failed
        self.assertEqual(result["state"], "failed")

    @patch('handler.boto3')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_success_experiment(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_boto3
    ):
        """Test that local_mode correctly handles successful experiments"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal

        event = {
            "local_mode": True,
            "experiment_source": self.test_experiment_path,
            "configuration": {"aws_region": "us-east-1"},
        }

        result = handler(event, MockContext())

        # Should update state to done
        self.assertEqual(result["state"], "done")
        
        # Should include response and report_capture
        self.assertIn("response", result)
        self.assertIn("report_capture", result)
        
        # Verify response contains journal
        response = json.loads(result["response"])
        self.assertEqual(response["status"], "completed")

    @patch('handler.boto3')
    @patch('handler.run_experiment')
    @patch('handler.load_experiment')
    @patch('handler.configure_logger')
    def test_local_mode_with_output_config_ignored(
        self,
        mock_configure_logger,
        mock_load_experiment,
        mock_run_experiment,
        mock_boto3
    ):
        """Test that local_mode ignores output_config even if provided"""
        # Setup mocks
        mock_experiment = {"title": "Test Experiment"}
        mock_load_experiment.return_value = mock_experiment
        mock_run_experiment.return_value = self.mock_journal

        event = {
            "local_mode": True,
            "experiment_source": self.test_experiment_path,
            "configuration": {"aws_region": "us-east-1"},
            "output_config": {
                "S3": {
                    "bucket_name": "output-bucket",
                    "path": "journals/",
                },
                "OPENSEARCH": {
                    "index": "test-index",
                    "host": "test-host",
                },
            },
        }

        result = handler(event, MockContext())

        # Should still work and not upload to S3/OpenSearch
        self.assertEqual(result["state"], "done")
        # DynamoDB should not be called
        mock_boto3.Session.assert_not_called()


if __name__ == '__main__':
    unittest.main()
