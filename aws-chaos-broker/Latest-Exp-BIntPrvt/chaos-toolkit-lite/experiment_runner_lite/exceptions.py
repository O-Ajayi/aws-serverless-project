__all__ = [
    "ChaosException",
    "ActivityFailed",
    "InvalidActivity",
    "InvalidExperiment"
]

class ChaosException(Exception):
    pass

class ActivityFailed(Exception):
    pass

class InvalidActivity(ChaosException):
    pass

class InvalidExperiment(ChaosException):
    pass

class InvalidSource(ChaosException):
    pass