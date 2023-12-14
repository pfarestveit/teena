"""
Minimal Ripley load test script for use with the Locust tool (https://locust.io).

Usage:

From the top-level Teena directory, install dependencies.
pip3 install -r requirements.txt

Start Locust with this file.
locust -f load_tests/ripley_locust.py

In your browser, go to localhost:8089 to start tests and view charts.

Visit https://locust.io for more information.
"""


import os
import random

from locust import HttpUser, task
import yaml


"""
Config
"""


def merge_recursive(target, source):
    for key in source:
        if key in target and isinstance(target[key], dict) and isinstance(source[key], dict):
            merge_recursive(target[key], source[key])
        else:
            target[key] = source[key]


with open('settings.yml') as config_yml:
    configs = yaml.safe_load(config_yml)
with open(os.environ.get('HOME') + '/.webdriver-config/settings.yml') as local_config_yml:
    local_configs = yaml.safe_load(local_config_yml)
merge_recursive(configs, local_configs)


ripley_cfg = configs['ripley']


"""
Test Data
"""


def sample(_list):
    return _list[random.randint(0, len(_list) - 1)]


class TestData:
    with open(os.environ.get('HOME') + '/.webdriver-config/canvas_ids.txt') as canvas_id_file:
        canvas_ids = [canvas_id.rstrip() for canvas_id in canvas_id_file.readlines()]


"""
Hatch a locust.
"""


class RipleyUser(HttpUser):
    host = ripley_cfg['base_url']
    min_wait = 1000
    max_wait = 3000

    @task(2)
    def can_create_site(self):
        canvas_id = sample(TestData.canvas_ids)
        self.client.get(f'/api/canvas/can_user_create_site?canvas_user_id={canvas_id}')

    @task(1)
    def external_tools(self):
        self.client.get('/api/canvas/external_tools')
