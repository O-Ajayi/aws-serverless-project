import datetime
import logging
import numbers
import os
import json
import yaml
import requests
import sys
from pprint import pformat
import traceback
import unittest
import urllib.parse
from typing import Dict, Any, Optional
from experiment_runner_lite.exceptions import InvalidActivity, InvalidExperiment, InvalidSource
from experiment_runner_lite.logging import logger
from experiment_runner_lite.exceptions import InvalidExperiment
from experiment_runner_lite.types import Action
from experiment_runner_lite import method
from requests.exceptions import JSONDecodeError
from urllib.parse import urlparse

def validate_activity(activity: dict):
    if not activity:
        raise InvalidActivity("Empty activity is no activity")

    ref = activity.get("ref")
    if ref is not None:
       if not isinstance(ref, str) or ref == "":
            raise InvalidActivity("Reference to activity must not be empty strings")

    activity_type = activity.get("type")
    if not activity_type:
        raise InvalidActivity("Activity must have a type")

    if activity_type not in ('prove', 'action'):
        raise InvalidActivity(f"'{activity_type}' is not a supported activity type")

    if not activity.get("name"):
       raise InvalidActivity("Activity must have a name")

    provider = activity.get('provider')
    if not provider:
        raise InvalidActivity("Activity must have a provider")

    provider_type = provider.get("type")
    if not provider_type:
        raise InvalidActivity("a provider must have a type")

    if provider_type not in ("python", "process", "http"):
        raise InvalidActivity(f"unknown provider type ({provider_type})")

    if not activity.get("name"):
        raise InvalidActivity("activity must have a name (cannot be empty)")

    timeout = activity.get("timeout")
    if timeout is not None:
        if not isinstance(timeout, numbers.Number):
            raise InvalidActivity("activity timeout must be a number")

    if "background" in activity:
        if not isinstance(activity["background"], bool):
            raise InvalidActivity("activity background must be a boolean")

    return True


def validate_experiment(experiment: dict):
    logger.info("Validating the experiment's syntax")

    if not experiment:
        raise InvalidExperiment("an empty experiment is not an experiment")

    if not experiment.get("title"):
        raise InvalidExperiment("experiment requires a title")

    if not experiment.get("description"):
        raise InvalidExperiment("experiment requires a description") #"experiment requires a description”
                                
    tags = experiment.get("tags")
    if tags:
        if list(filter(lambda t: t == "" or not isinstance(t, str), tags)):
            raise InvalidExperiment("experiment tags must be a non-empty string")

    method = experiment.get("method")
    if method is None:
        raise InvalidExperiment(
            "an experiment requires a method, "
            "which can be empty for only checking steady state hypothesis"
        )

    for activity in method:
        validate_activity(activity)

    logger.info("Experiment looks valid")

    return True

# Runs probe activities and checks steady state
def run_steady_state_probes(probe_list, experiment_config: dict):
    logging.info("Run steady state probes")
    probe_outputs = run_activities(probe_list, experiment_config)
    steady_state_met = True

    # Check tolerance met in probe output
    for probe_output in probe_outputs:
        if "tolerance_met" in probe_output:
            if probe_output["tolerance_met"] == False:
                steady_state_met = False

    return {"steady_state_met": steady_state_met, "probes": probe_output}

# Runs a list of activities and returns outputs
def run_activities(activity_list: list, experiment_config: dict):
    logger.info("Run activities")
    activities = []
    for activity in activity_list:
        logger.info(f"Activity: {pformat(activity)}")
        tolerance = False
        if "tolerance" in activity:
            if activity["tolerance"]:
                tolerance = True

        activity_output = method.execute(
            module=activity["provider"]["module"],
            func=activity["provider"]["func"],
            arguments=activity["provider"]["arguments"],
            tolerance=tolerance,
            experiment_config=experiment_config,
        )

        logger.info(f"Activity output: {pformat(activity_output)}")

        activity_output["activity"] = activity
        activities.append(activity_output)

    return activities


# Stub for method.execute (Should be deleted)
def execute(
    module: str, func: str, arguments: Dict[str, Any], tolerance, experiment_config: dict
):
    start_time = datetime.datetime.now()
    end_time = datetime.datetime.now()
    duration = end_time - start_time

    return {
        "output": True,
        "start": start_time.isoformat(),

        "duration": duration.total_seconds(),
        "tolerance_met": True,
    }


def load_experiment(experiment_source: str):
    if os.path.exists(experiment_source):
        with open(experiment_source, encoding="utf-8") as f:
            path, extention = os.path.splitext(experiment_source)
            if extention in [".yaml", ".yml"]:
                try:
                    return yaml.safe_load(f)
                except Exception as e:
                    raise InvalidSource(f"Failed parsing YAML experiment: {str(e)}")
            elif extention == ".json":
                try:
                    return json.load(f)
                except Exception as e:
                    raise InvalidSource(f"Failed parsing JSON Experiment: {str(e)}")
            else:
                raise InvalidSource(
                f"Unable to load experiment, unsupported file type: {extention}"
                )
    else:
        headers = {"Accept": "application/json, application/x-yaml"}
        r = requests.get(experiment_source, headers=headers, timeout=60)
        if r.status_code != 200:
            raise InvalidSource(f"Failed to fetch the experiment: {r.text}")
        content_type = r.headers.get("Content-Type")
        if "application/json" == content_type:
            try:
                return json.loads(r.text)
            except JSONDecodeError as e:
                raise InvalidSource(f"Failed parsing JSON experiment: {str(e)}")
        elif "text/yaml" in content_type or "application/x-yaml" in content_type:
            try:
                return yaml.safe_load(r.text)
            except yaml.YAMLError as e:
                raise InvalidSource(f"Failed parsing YAML experiment: {str(e)}")
        elif "text/plain" in content_type:
            try:
                return r.json()
            except JSONDecodeError:
                try:
                    return yaml.safe_load(r.text)
                except yaml.YAMLError:
                    raise InvalidSource(f"Failed parsing plaintext experiment: {str(e)}")

def load_experiment_from_object(obj, content_type: str):
    logger.info("loading experiment from object")
    logger.info(f"content_type: {content_type}")
    if "application/json" == content_type:
        try:
            return json.loads(obj)
        except JSONDecodeError as e:
            raise InvalidSource(f"Failed parsing JSON experiment: {str(e)}")
    elif content_type in ["text/yaml", "application/x-yaml", "application/yaml"]:
        try:
            return yaml.safe_load(obj)
        except yaml.YAMLError as e:
            raise InvalidSource(f"Failed parsing YAML experiment: {str(e)}")
    elif "text/plain" in content_type:
        try:
            return json.loads(obj)
        except JSONDecodeError:
            try:
                return yaml.safe_load(obj)
            except yaml.YAMLError:
                raise InvalidSource(f"Failed parsing plaintext experiment: {str(e)}")

def run_experiment(experiment: dict):
    """Execute a chaos experiment and return the resulting journal."""

    status: Optional[str] = None
    deviated: Optional[bool] = None
    steady_states: Dict[str, Dict[str, Any]] = {}
    rollbacks: list = []
    experiment_start_time: Optional[datetime.datetime] = None

    # Always initialise an experiment journal so the exception path can safely
    # enrich it without raising UnboundLocalError when early failures occur
    # (e.g. during validation).
    experiment_journal: dict = {
        "experiment": experiment or {},
        "run": [],
        "rollbacks": [],
    }

    try:
        validate_experiment(experiment)
        experiment_start_time = datetime.datetime.now()
        status = "completed"
        deviated = False

        logging.info("Start experiment journal")
        experiment_journal.update(
            {
                "chaoslib-version": "NA",
                "platform": "Linux-5.10.201-213.748.amzn2.x86_64-x86_64-with-glibc2.26",
                "node": "169.254.68.133",
                "start": experiment_start_time.isoformat(),
            }
        )

        # Check Pre Execution Steady State Hypothesis
        logger.info("Check Pre Execution Steady State Hypothesis")
        steady_states = {
            "before": run_steady_state_probes(
            experiment["steady-state-hypothesis"]["probes"],
            experiment["configuration"],
            )
        }

        if steady_states["before"]["steady_state_met"]:
            # Execute Method
            experiment_journal["run"] = run_activities(
                experiment["method"], experiment["configuration"]
            )
            # if steady_states[before]["steady_state_met"]:
            # Execute Method
            experiment_journal["run"] = run_activities(
                experiment["method"], experiment["configuration"]
            )

            # Check Post Execution Steady State Hypothesis
            logger.info("Check Post Execution Steady State Hypothesis")
            steady_states["after"] = run_steady_state_probes(
                experiment["steady-state-hypothesis"]["probes"],
                experiment["configuration"],
            )
            steady_states["during"] = []

            if not steady_states["after"].get("steady_state_met", False):
                deviated = True
                status = "failed"

            else:
                logging.info("Post steady state hypothesis satisfied")

            try:
                if experiment["rollbacks"]:
                    logging.info("Running rollbacks")
                    experiment_journal["rollbacks"] = run_activities(
                        experiment["rollbacks"], experiment["configuration"]
                    )
            except KeyError:
                logger.info("No Rollbacks found")

            experiment_end_time = datetime.datetime.now()

            experiment_journal["status"] = status
            experiment_journal["deviated"] = deviated
            experiment_journal["steady_states"] = steady_states
            experiment_journal["rollbacks"] = []
            experiment_journal["end"] = experiment_end_time.isoformat()
            experiment_journal["duration"] = (
            (experiment_end_time - experiment_start_time).total_seconds()
            if experiment_start_time is not None
            else 0
        )

        # print(experiment_journal)

        return experiment_journal

    except Exception as e:
        logger.error(f"Experiment Aborted.")
        logger.error(traceback.format_exc())

        status = "aborted"
        experiment_end_time = datetime.datetime.now()

        experiment_journal.setdefault("steady_states", steady_states)
        experiment_journal.setdefault("rollbacks", [])
        experiment_journal.setdefault("run", [])
        experiment_journal["status"] = status
        experiment_journal["deviated"] = deviated if deviated is not None else True
        experiment_journal["end"] = experiment_end_time.isoformat()
        experiment_journal["duration"] = (
            (experiment_end_time - experiment_start_time).total_seconds()
            if experiment_start_time is not None
            else 0
        )

        return experiment_journal