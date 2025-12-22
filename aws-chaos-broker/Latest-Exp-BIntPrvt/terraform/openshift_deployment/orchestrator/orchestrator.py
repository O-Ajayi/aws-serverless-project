#!/usr/bin/env python3
"""
Orchestrator service that replaces AWS Step Functions for OpenShift deployment.
Implements the same state machine logic as the AWS Step Functions definition.
"""

import os
import json
import logging
import time
import requests
import traceback
from typing import Dict, Any, List, Optional
from datetime import datetime
import concurrent.futures
from enum import Enum

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ExecutionState(Enum):
    """Execution states for experiments."""
    PENDING = "pending"
    RUNNING = "running"
    DONE = "done"
    FAILED = "failed"


class ExperimentOrchestrator:
    """
    Orchestrator that manages experiment execution workflow.
    Replaces AWS Step Functions state machine functionality.
    """
    
    def __init__(self, handler_service_url: str = None, max_concurrency: int = 1):
        """
        Initialize the orchestrator.
        
        Args:
            handler_service_url: URL of the handler HTTP service (default: from env or localhost)
            max_concurrency: Maximum concurrent experiment executions
        """
        self.handler_service_url = handler_service_url or os.environ.get(
            'HANDLER_SERVICE_URL', 
            'http://localhost:8080'
        )
        self.max_concurrency = max_concurrency
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=max_concurrency)
    
    def invoke_handler(self, payload: Dict[str, Any], timeout: int = 300) -> Dict[str, Any]:
        """
        Invoke the handler service with a payload.
        
        Args:
            payload: Event payload to send to handler
            timeout: Request timeout in seconds
            
        Returns:
            Response from handler service
        """
        url = f"{self.handler_service_url}/invoke"
        
        try:
            logger.info(f"Invoking handler service at {url}")
            logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
            
            response = requests.post(
                url,
                json=payload,
                headers={'Content-Type': 'application/json'},
                timeout=timeout
            )
            
            response.raise_for_status()
            result = response.json()
            
            # Extract body if nested in statusCode/body structure
            if isinstance(result, dict) and 'body' in result:
                return result['body']
            
            return result
        
        except requests.exceptions.RequestException as e:
            logger.error(f"Handler service request failed: {str(e)}")
            raise
    
    def process_experiment(self, experiment_config: Dict[str, Any], max_attempts: int = 2) -> Dict[str, Any]:
        """
        Process a single experiment with retry logic.
        Implements the ProcessPayload state from Step Functions.
        
        Args:
            experiment_config: Experiment configuration
            max_attempts: Maximum retry attempts
            
        Returns:
            Result dictionary with state and data
        """
        attempt = 0
        
        while attempt < max_attempts:
            attempt += 1
            logger.info(f"Processing experiment (attempt {attempt}/{max_attempts}): {experiment_config.get('experiment_source', 'unknown')}")
            
            try:
                # Set state to pending
                experiment_config['state'] = ExecutionState.PENDING.value
                
                # Invoke handler
                result = self.invoke_handler(experiment_config)
                
                # Check result state
                result_state = result.get('state', 'unknown')
                
                if result_state == ExecutionState.DONE.value:
                    logger.info(f"Experiment completed successfully: {experiment_config.get('experiment_source')}")
                    return {
                        'state': ExecutionState.DONE.value,
                        'data': result,
                        'experiment': experiment_config
                    }
                elif result_state == ExecutionState.PENDING.value:
                    # Wait and retry (implements IsPendingState wait)
                    wait_seconds = 15
                    logger.info(f"Experiment still pending, waiting {wait_seconds} seconds before retry...")
                    time.sleep(wait_seconds)
                    continue
                else:
                    # Failed state
                    logger.warning(f"Experiment failed with state: {result_state}")
                    if attempt < max_attempts:
                        logger.info(f"Retrying experiment (attempt {attempt + 1}/{max_attempts})...")
                        continue
                    else:
                        return {
                            'state': ExecutionState.FAILED.value,
                            'data': result,
                            'experiment': experiment_config,
                            'error': f"Experiment failed after {max_attempts} attempts"
                        }
            
            except Exception as e:
                logger.error(f"Error processing experiment: {str(e)}")
                logger.error(traceback.format_exc())
                
                if attempt < max_attempts:
                    logger.info(f"Retrying experiment after error (attempt {attempt + 1}/{max_attempts})...")
                    time.sleep(5)  # Wait before retry
                    continue
                else:
                    return {
                        'state': ExecutionState.FAILED.value,
                        'experiment': experiment_config,
                        'error': str(e)
                    }
        
        return {
            'state': ExecutionState.FAILED.value,
            'experiment': experiment_config,
            'error': f"Experiment failed after {max_attempts} attempts"
        }
    
    def run_workflow(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run the complete workflow orchestration.
        Implements the Step Functions state machine logic.
        
        Args:
            payload: Workflow payload with structure:
                {
                    "Payload": {
                        "list": [
                            {
                                "experiment_source": "...",
                                "bucket_name": "...",
                                ...
                            }
                        ],
                        "state": "pending"
                    }
                }
        
        Returns:
            Workflow execution result
        """
        import traceback
        
        start_time = datetime.now()
        
        try:
            # Extract payload (handle both nested and flat structures)
            if 'Payload' in payload:
                workflow_payload = payload['Payload']
            else:
                workflow_payload = payload
            
            # Check initial state (FirstChoiceState logic)
            initial_state = workflow_payload.get('state', ExecutionState.PENDING.value)
            
            if initial_state == ExecutionState.DONE.value:
                logger.info("Workflow already in done state, exiting")
                return {
                    'state': ExecutionState.DONE.value,
                    'message': 'Workflow already completed'
                }
            
            if initial_state != ExecutionState.PENDING.value:
                logger.warning(f"Unexpected initial state: {initial_state}, defaulting to pending")
                initial_state = ExecutionState.PENDING.value
            
            # Get experiment list (MapState logic)
            experiment_list = workflow_payload.get('list', [])
            
            if not experiment_list:
                logger.warning("No experiments in list, nothing to execute")
                return {
                    'state': ExecutionState.DONE.value,
                    'results': [],
                    'message': 'No experiments to execute'
                }
            
            logger.info(f"Starting workflow orchestration for {len(experiment_list)} experiment(s)")
            logger.info(f"Max concurrency: {self.max_concurrency}")
            
            # Process experiments (MapState with MaxConcurrency)
            results = []
            
            if self.max_concurrency == 1:
                # Sequential execution
                for idx, experiment_config in enumerate(experiment_list, 1):
                    logger.info(f"Processing experiment {idx}/{len(experiment_list)}")
                    result = self.process_experiment(experiment_config)
                    results.append(result)
            else:
                # Concurrent execution (limited by max_concurrency)
                future_to_experiment = {
                    self.executor.submit(self.process_experiment, exp): exp 
                    for exp in experiment_list
                }
                
                for future in concurrent.futures.as_completed(future_to_experiment):
                    experiment = future_to_experiment[future]
                    try:
                        result = future.result()
                        results.append(result)
                    except Exception as e:
                        logger.error(f"Experiment execution raised exception: {str(e)}")
                        results.append({
                            'state': ExecutionState.FAILED.value,
                            'experiment': experiment,
                            'error': str(e)
                        })
            
            # Determine overall workflow state
            all_done = all(r.get('state') == ExecutionState.DONE.value for r in results)
            any_failed = any(r.get('state') == ExecutionState.FAILED.value for r in results)
            
            if all_done:
                final_state = ExecutionState.DONE.value
            elif any_failed:
                final_state = ExecutionState.FAILED.value
            else:
                final_state = ExecutionState.DONE.value  # Default to done if no failures
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            workflow_result = {
                'state': final_state,
                'results': results,
                'total_experiments': len(experiment_list),
                'successful': sum(1 for r in results if r.get('state') == ExecutionState.DONE.value),
                'failed': sum(1 for r in results if r.get('state') == ExecutionState.FAILED.value),
                'duration_seconds': duration,
                'start_time': start_time.isoformat(),
                'end_time': end_time.isoformat()
            }
            
            logger.info(f"Workflow orchestration completed: {workflow_result['successful']} successful, {workflow_result['failed']} failed")
            
            return workflow_result
        
        except Exception as e:
            logger.error(f"Workflow orchestration failed: {str(e)}")
            logger.error(traceback.format_exc())
            return {
                'state': ExecutionState.FAILED.value,
                'error': str(e),
                'traceback': traceback.format_exc()
            }


def main():
    """CLI entry point for orchestrator."""
    import argparse
    import sys
    
    parser = argparse.ArgumentParser(description='Chaos Broker Orchestrator')
    parser.add_argument('--payload-file', type=str, help='Path to JSON payload file')
    parser.add_argument('--handler-url', type=str, help='Handler service URL')
    parser.add_argument('--max-concurrency', type=int, default=1, help='Max concurrent experiments')
    
    args = parser.parse_args()
    
    # Read payload
    if args.payload_file:
        with open(args.payload_file, 'r') as f:
            payload = json.load(f)
    else:
        # Read from stdin
        payload = json.load(sys.stdin)
    
    # Create orchestrator
    orchestrator = ExperimentOrchestrator(
        handler_service_url=args.handler_url,
        max_concurrency=args.max_concurrency
    )
    
    # Run workflow
    result = orchestrator.run_workflow(payload)
    
    # Output result
    print(json.dumps(result, indent=2, default=str))
    
    # Exit with appropriate code
    sys.exit(0 if result.get('state') == 'done' else 1)


if __name__ == '__main__':
    main()

