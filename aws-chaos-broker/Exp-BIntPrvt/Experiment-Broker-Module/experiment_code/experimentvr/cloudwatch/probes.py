import boto3
import os
import random

from logzero import logger
from time import sleep


def probe_alarm_state(alarm_name, alarm_state):
    logger.info(f"Probing Alarm {alarm_name}")
    sleep(3)
    discovered_alarm_state = random.choice(["OK", "ALARM", "INSUFFICIENT_DATA"])
    match = alarm_name == alarm_state
    logger.info(
        f"Alarm State is {discovered_alarm_state}, Expected: {alarm_state}, Match: {match}"
    )
    return {"match": match, "alarm_state": discovered_alarm_state}
