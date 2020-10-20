"""
Minimal Junction load test script for use with the Locust tool (https://locust.io).

Usage:

From the top-level Teena directory, install dependencies.
pip -r requirements.txt

Start Locust with this file.
locust -f load_tests/junction_locust.py

In your browser, go to localhost:8089 to start tests and view charts.

Visit https://locust.io for more information.
"""


import os
import random
import yaml

from locust import HttpLocust, TaskSet, task


"""
Define utility functions.
"""


def merge_recursive(target, source):
    for key in source:
        if key in target and isinstance(target[key], dict) and isinstance(source[key], dict):
            merge_recursive(target[key], source[key])
        else:
            target[key] = source[key]


def sample(_list):
    return _list[random.randint(0, len(_list) - 1)]


"""
Set configurations.
"""


with open('settings.yml') as config_yml:
    configs = yaml.safe_load(config_yml)
with open(os.environ.get('HOME') + '/.webdriver-config/settings.yml') as local_config_yml:
    local_configs = yaml.safe_load(local_config_yml)
merge_recursive(configs, local_configs)


junction_cfg = configs['junction']


class TestData:

    with open(os.environ.get('HOME') + '/.webdriver-config/canvas_ids.txt') as canvas_id_file:
        canvas_ids = [id.rstrip() for id in canvas_id_file.readlines()]


"""
Define user tasks.
"""


class JunctionTaskSet(TaskSet):

    @task(1)
    def can_create_site(self):
        canvas_id = sample(TestData.canvas_ids)
        self.client.get(f'/api/academics/canvas/user_can_create_site?canvas_user_id={canvas_id}')

    @task(2)
    def external_tools(self):
        self.client.get('/api/academics/canvas/external_tools')


"""
Hatch a locust.
"""


class JunctionLocust(HttpLocust):
    task_set = JunctionTaskSet
    host = junction_cfg['base_url']
    min_wait = 1000
    max_wait = 3000

    def __init__(self):
        super(JunctionLocust, self).__init__()
