import logging
import uuid
from logging.handlers import RotatingFileHandler

__all__ = ["logger", "configure_logger"]

class ContextFilter(logging.Filter):
    def __init__(self, name: str = "", context_id: str = None):
        logging.Filter.__init__(self, name)
        self.context_id = context_id or str(uuid.uuid4())

class LogFormatter(logging.Formatter):
    def __init__(self, verbose: bool = False):
        grey = "\033[1;30m"
        white = "\033[1;37m"
        yellow = "\033[1;33m"
        red = "\033[1;31m"
        bold_red = "\033[1;41m"
        reset = "\033[0m"
        fmt = "[%(asctime)s %(levelname)s]"
        verbose_fmt = (
            "[%(asctime)s %(levelname)s]"
            "[%(module)s:%(lineno)d]"
        )
        message = "%(message)s"

        # cloudWatch does not support colors
        # self.colors = {
        #     logging.DEBUG: grey + fmt + reset + message,
        #     logging.INFO: white + fmt + reset + message,
        #     logging.WARNING: yellow + fmt + reset + message,
        #     logging.ERROR: red + fmt + reset + message,
        #     logging.CRITICAL: bold_red + fmt + reset + message,
        # }
        self.colors = {
            logging.DEBUG: fmt + message,
            logging.INFO: fmt + message,
            logging.WARNING: fmt + message,
            logging.ERROR: fmt + message,
            logging.CRITICAL: fmt + message,
        }

        if verbose:
            # CloudWatch does not support colors
            # self.colors = {
            #     logging.DEBUG: grey + verbose_fmt + reset + message,
            #     logging.INFO: white + verbose_fmt + reset + message,
            #     logging.WARNING: yellow + verbose_fmt + reset + message,
            #     logging.ERROR: red + verbose_fmt + reset + message,
            #     logging.CRITICAL: bold_red + verbose_fmt + reset + message,
            # }
            self.colors = {
                logging.DEBUG: verbose_fmt + message,
                logging.INFO: verbose_fmt + message,
                logging.WARNING: verbose_fmt + message,
                logging.ERROR: verbose_fmt + message,
                logging.CRITICAL: verbose_fmt + message,
            }

    def format(self, record):
        log_fmt = self.colors.get(record.levelno)
        formatter = logging.Formatter(log_fmt, datefmt="%Y-%m-%d %H:%M:%S")
        return formatter.format(record)


def _setup_default_logger() -> logging.Logger:
    _logger = logging.getLogger()
    _logger.setLevel(logging.INFO)
    _logger.propagate = False
    for _handler in _logger.handlers:
        _logger.removeHandler(_handler)
    _handler = logging.StreamHandler()
    _handler.setLevel(logging.INFO)
    _handler.setFormatter(LogFormatter())
    _logger.addHandler(_handler)
    return _logger

logger = _setup_default_logger()

def configure_logger(
    verbose: bool = False,
    log_format: str = "string",
    log_file: str = None,
    log_file_level: str = "debug",
    logger_name: str = None,
    context_id: str = None,
) -> logging.Logger:
    log_level = logging.INFO if not verbose else logging.DEBUG
    _formatter = LogFormatter(verbose=verbose)

    _logger = logging.getLogger(logger_name)
    _logger.propagate = False
    _logger.setLevel(log_level)

    for _handler in _logger.handlers:
        _logger.removeHandler(_handler)
    
    _handler = logging.StreamHandler()
    _handler.setLevel(log_level)
    _handler.setFormatter(_formatter)
    _logger.addHandler(_handler)

    if context_id:
        _logger.addFilter(ContextFilter(logger_name, context_id))

    if log_file:
        _logger.setLevel(logging.DEBUG)
        log_file_level = logging.getLevelName(log_file_level.upper())
        _formatter = LogFormatter(verbose=True)
        _handler = RotatingFileHandler(log_file)
        _handler.setLevel(log_file_level)
        _handler.setFormatter(_formatter)
        _logger.addHandler(_handler)

    return _logger