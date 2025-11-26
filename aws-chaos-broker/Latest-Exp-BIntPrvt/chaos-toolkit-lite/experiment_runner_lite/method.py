import importlib
import traceback
import re
import datetime
from typing import Dict, Any

from experiment_runner_lite.logging import logger
from experiment_runner_lite.exceptions import InvalidActivity


def _substitute_variables(value: Any, replacement_map: Dict[str, Any]) -> Any:
    """
    Recursively substitute ${variable} placeholders in values with values from replacement_map.
    
    Args:
        value: The value to substitute (can be str, dict, list, or other)
        replacement_map: Dictionary mapping variable names to replacement values
        
    Returns:
        Value with substitutions applied
    """
    if isinstance(value, str):
        # Match ${variable} pattern
        pattern = r'\$\{\s*([^}]+)\s*\}'
        
        def replace_var(match):
            var_name = match.group(1).strip()
            replacement = replacement_map.get(var_name)
            if replacement is None:
                logger.warning(f"Variable '${var_name}' not found in configuration, keeping placeholder")
                return match.group(0)  # Return original if not found
            return str(replacement)
        
        return re.sub(pattern, replace_var, value)
    elif isinstance(value, dict):
        return {k: _substitute_variables(v, replacement_map) for k, v in value.items()}
    elif isinstance(value, list):
        return [_substitute_variables(item, replacement_map) for item in value]
    else:
        return value

def apply_config():
    pass

def execute(
    module: str, 
    func: str, 
    arguments: Dict[str, Any], 
    tolerance: bool, 
    experiment_config: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Execute an activity by dynamically loading a module and calling a function.
    
    Args:
        module: The module path (e.g., 'experiment_bofa.k8s.probes')
        func: The function name to call (e.g., 'pod_is_ready')
        arguments: Dictionary of arguments to pass to the function
        tolerance: Whether tolerance should be applied to the result
        experiment_config: Experiment configuration dict
        
    Returns:
        Dictionary containing:
        - output: The result of the function call
        - start: ISO format start time
        - duration: Duration in seconds
        - tolerance_met: Whether tolerance was met (if tolerance=True)
    """
    start_time = datetime.datetime.now()
    
    try:
        # Dynamically import the module
        logger.debug(f"Importing module: {module}")
        mod = importlib.import_module(module)
        
        # Get the function from the module
        if not hasattr(mod, func):
            raise InvalidActivity(f"Function '{func}' not found in module '{module}'")
        
        func_obj = getattr(mod, func)
        
        # Substitute variables in arguments using values from experiment_config
        # This handles ${variable} placeholders in the arguments
        call_args = _substitute_variables(arguments, experiment_config)
        
        # Some functions may expect 'configuration' parameter
        # Check if function signature accepts it
        import inspect
        sig = inspect.signature(func_obj)
        if 'configuration' in sig.parameters:
            call_args['configuration'] = experiment_config
        
        # Call the function
        logger.debug(f"Calling {module}.{func} with arguments: {call_args}")
        result = func_obj(**call_args)
        
        # Determine if tolerance was met
        tolerance_met = True
        if tolerance:
            # If result is a boolean, use it directly
            # Otherwise, check if result indicates success
            if isinstance(result, bool):
                tolerance_met = result
            elif isinstance(result, dict):
                # Check for common success indicators
                tolerance_met = result.get('success', result.get('tolerance_met', True))
            else:
                # For other types, assume success if result is truthy
                tolerance_met = bool(result)
        
        end_time = datetime.datetime.now()
        duration = end_time - start_time
        
        return {
            "output": result,
            "start": start_time.isoformat(),
            "duration": duration.total_seconds(),
            "tolerance_met": tolerance_met,
        }
        
    except ImportError as e:
        logger.error(f"Failed to import module '{module}': {e}")
        raise InvalidActivity(f"Failed to import module '{module}': {str(e)}")
    except AttributeError as e:
        logger.error(f"Failed to get function '{func}' from module '{module}': {e}")
        raise InvalidActivity(f"Function '{func}' not found in module '{module}'")
    except Exception as e:
        logger.error(f"Error executing {module}.{func}: {e}")
        logger.error(traceback.format_exc())
        end_time = datetime.datetime.now()
        duration = end_time - start_time
        
        # Return failure result
        return {
            "output": None,
            "error": str(e),
            "start": start_time.isoformat(),
            "duration": duration.total_seconds(),
            "tolerance_met": False,
        }
