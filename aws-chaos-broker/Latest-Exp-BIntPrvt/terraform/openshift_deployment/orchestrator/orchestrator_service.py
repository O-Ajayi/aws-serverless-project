#!/usr/bin/env python3
"""
HTTP service wrapper for the orchestrator.
Accepts workflow payloads via REST API and orchestrates experiment execution.
"""

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import traceback
from typing import Dict, Any

# Import the orchestrator
import sys
sys.path.insert(0, '/app')
from orchestrator import ExperimentOrchestrator, ExecutionState

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PORT = int(os.environ.get('ORCHESTRATOR_PORT', 8081))


class OrchestratorHTTPRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for orchestrator service."""
    
    def _set_headers(self, status_code: int = 200, content_type: str = 'application/json'):
        """Set HTTP response headers."""
        self.send_response(status_code)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def _send_json_response(self, data: Dict[str, Any], status_code: int = 200):
        """Send JSON response."""
        self._set_headers(status_code)
        response = json.dumps(data, indent=2, default=str)
        self.wfile.write(response.encode('utf-8'))
    
    def _send_error(self, error_message: str, status_code: int = 500, error_type: str = "InternalServerError"):
        """Send error response."""
        error_data = {
            "errorType": error_type,
            "errorMessage": error_message,
            "statusCode": status_code
        }
        self._send_json_response(error_data, status_code)
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests."""
        self._set_headers(200)
    
    def do_GET(self):
        """Handle GET requests."""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/health':
            self._send_json_response({
                "status": "healthy",
                "service": "chaos-broker-orchestrator",
                "version": "1.0.0"
            })
        elif parsed_path.path == '/':
            self._send_json_response({
                "service": "chaos-broker-orchestrator",
                "version": "1.0.0",
                "endpoints": {
                    "POST /execute": "Execute workflow with payload",
                    "GET /health": "Health check endpoint"
                }
            })
        else:
            self._send_error("Not Found", 404, "NotFound")
    
    def do_POST(self):
        """Handle POST requests to execute workflows."""
        if self.path != '/execute':
            self._send_error("Not Found. Use POST /execute", 404, "NotFound")
            return
        
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            if not body:
                self._send_error("Request body is required", 400, "BadRequest")
                return
            
            # Parse JSON payload
            try:
                payload = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError as e:
                self._send_error(f"Invalid JSON: {str(e)}", 400, "BadRequest")
                return
            
            logger.info(f"Received workflow execution request")
            logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
            
            # Get handler service URL from environment
            handler_service_url = os.environ.get(
                'HANDLER_SERVICE_URL',
                'http://chaos-broker-handler:8080'
            )
            
            # Get max concurrency from payload or environment
            max_concurrency = payload.get('max_concurrency') or int(os.environ.get('MAX_CONCURRENCY', '1'))
            
            # Create orchestrator instance
            orchestrator = ExperimentOrchestrator(
                handler_service_url=handler_service_url,
                max_concurrency=max_concurrency
            )
            
            # Ensure experiment_source paths point to persistent volume
            # If payload has Payload.list, normalize experiment_source paths
            workflow_payload = payload.get('Payload', payload)
            experiment_list = workflow_payload.get('list', [])
            
            # Default persistent volume path for experiments
            persistent_volume_path = os.environ.get(
                'PERSISTENT_VOLUME_PATH',
                '/app/local_only'
            )
            experiments_dir = os.path.join(persistent_volume_path, 'experiments')
            
            # Normalize experiment_source paths to point to persistent volume
            # Experiments should be stored in /app/local_only/experiments/ in the persistent volume
            for experiment_config in experiment_list:
                experiment_source = experiment_config.get('experiment_source')
                if experiment_source:
                    # If path is relative, resolve to experiments directory in persistent volume
                    if not os.path.isabs(experiment_source):
                        # Relative path: resolve to experiments directory
                        experiment_source = os.path.join(experiments_dir, experiment_source)
                    elif not experiment_source.startswith(persistent_volume_path):
                        # Absolute path but outside our volume, extract filename and use experiments dir
                        filename = os.path.basename(experiment_source)
                        experiment_source = os.path.join(experiments_dir, filename)
                    
                    # Ensure openshift mode is set
                    experiment_config['local_mode'] = 'openshift'
                    experiment_config['experiment_source'] = experiment_source
                    
                    # Set openshift_storage_path if not provided (handler needs this)
                    if 'openshift_storage_path' not in experiment_config:
                        experiment_config['openshift_storage_path'] = persistent_volume_path
                    
                    logger.info(f"Normalized experiment_source to: {experiment_source}")
            
            # Execute workflow
            try:
                result = orchestrator.run_workflow(payload)
                logger.info(f"Workflow execution completed: {result.get('state')}")
                
                # Send success response
                self._send_json_response({
                    "statusCode": 200,
                    "body": result
                }, 200)
            
            except Exception as e:
                logger.error(f"Workflow execution failed: {str(e)}")
                logger.error(traceback.format_exc())
                
                # Send error response
                error_data = {
                    "errorType": type(e).__name__,
                    "errorMessage": str(e),
                    "traceback": traceback.format_exc()
                }
                self._send_json_response(error_data, 500)
        
        except Exception as e:
            logger.error(f"Request processing failed: {str(e)}")
            logger.error(traceback.format_exc())
            self._send_error(f"Internal server error: {str(e)}", 500)
    
    def log_message(self, format, *args):
        """Override to use Python logging instead of stderr."""
        logger.info("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args))


def main():
    """Start the HTTP server."""
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, OrchestratorHTTPRequestHandler)
    
    handler_url = os.environ.get('HANDLER_SERVICE_URL', 'http://chaos-broker-handler:8080')
    
    logger.info(f"Starting chaos-broker orchestrator service on port {PORT}")
    logger.info(f"Health check: http://localhost:{PORT}/health")
    logger.info(f"Execute endpoint: POST http://localhost:{PORT}/execute")
    logger.info(f"Handler service URL: {handler_url}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

