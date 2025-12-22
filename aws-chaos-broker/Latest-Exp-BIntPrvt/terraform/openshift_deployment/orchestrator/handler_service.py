#!/usr/bin/env python3
"""
HTTP service wrapper for the chaos-broker handler.
Exposes the handler function via HTTP REST API for OpenShift/Kubernetes deployment.
"""

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import traceback
from typing import Dict, Any

# Import the handler function
import sys
sys.path.insert(0, '/app')
from handler import handler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PORT = int(os.environ.get('PORT', 8080))


class MockContext:
    """Mock Lambda context for handler compatibility."""
    def __init__(self):
        self.function_name = os.environ.get('FUNCTION_NAME', 'chaos-broker-handler')
        self.function_version = os.environ.get('FUNCTION_VERSION', '$LATEST')
        self.invoked_function_arn = os.environ.get('FUNCTION_ARN', 'arn:aws:lambda:local:123456789012:function:chaos-broker-handler')
        self.memory_limit_in_mb = os.environ.get('MEMORY_LIMIT', '512')
        self.aws_request_id = 'local-request-id'


class HandlerHTTPRequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for chaos-broker handler service."""
    
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
                "service": "chaos-broker-handler",
                "version": "1.0.0"
            })
        elif parsed_path.path == '/':
            self._send_json_response({
                "service": "chaos-broker-handler",
                "version": "1.0.0",
                "endpoints": {
                    "POST /invoke": "Invoke handler with experiment event",
                    "GET /health": "Health check endpoint"
                }
            })
        else:
            self._send_error("Not Found", 404, "NotFound")
    
    def do_POST(self):
        """Handle POST requests to invoke the handler."""
        if self.path != '/invoke':
            self._send_error("Not Found. Use POST /invoke", 404, "NotFound")
            return
        
        try:
            # Read request body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            if not body:
                self._send_error("Request body is required", 400, "BadRequest")
                return
            
            # Parse JSON event
            try:
                event = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError as e:
                self._send_error(f"Invalid JSON: {str(e)}", 400, "BadRequest")
                return
            
            logger.info(f"Received handler invocation request: {json.dumps(event, indent=2)}")
            
            # Create mock context
            context = MockContext()
            
            # Invoke handler
            try:
                result = handler(event, context)
                logger.info(f"Handler execution completed successfully")
                
                # Send success response
                self._send_json_response({
                    "statusCode": 200,
                    "body": result
                }, 200)
            
            except Exception as e:
                logger.error(f"Handler execution failed: {str(e)}")
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
    httpd = HTTPServer(server_address, HandlerHTTPRequestHandler)
    
    logger.info(f"Starting chaos-broker handler service on port {PORT}")
    logger.info(f"Health check: http://localhost:{PORT}/health")
    logger.info(f"Invoke endpoint: POST http://localhost:{PORT}/invoke")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down server...")
        httpd.shutdown()


if __name__ == '__main__':
    main()

