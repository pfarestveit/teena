"""
Squiggy load test script for use with the Locust tool (https://locust.io).

Usage:

From the top-level Teena directory, install dependencies.
pip3 install -r requirements.txt

Start Locust with this file.
locust -f load_tests/squiggy_locust.py

In your browser, go to localhost:8089 to start tests and view charts.

Visit https://locust.io for more information.
"""

import os
import random

from locust import between, HttpUser, task, TaskSet
import psycopg2
import psycopg2.extras
from pyquery import PyQuery
import yaml

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
CONFIG
"""

with open('settings.yml') as config_yml:
    configs = yaml.safe_load(config_yml)
with open(os.environ.get('HOME') + '/.webdriver-config/settings.yml') as local_config_yml:
    local_configs = yaml.safe_load(local_config_yml)
merge_recursive(configs, local_configs)

squiggy_cfg = configs['squiggy']

"""
DB
"""


class Rds:
    @classmethod
    def fetch(cls, sql, params=None):
        connection = psycopg2.connect(**cls.connection_params)
        cursor = connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute(sql, params)
        results = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        connection.close()
        return results


class SquiggyRds(Rds):
    connection_params = {
        'dbname': squiggy_cfg['db_name'],
        'user': squiggy_cfg['db_user'],
        'password': squiggy_cfg['db_password'],
        'host': squiggy_cfg['db_host'],
        'port': squiggy_cfg['db_port'],
    }


"""
TEST DATA
"""


class TestData:
    users = []

    busy_users = SquiggyRds.fetch(
        """SELECT users.id AS user_id,
                  users.course_id AS course_id,
                  ARRAY_AGG(assets.id)
             FROM users
             JOIN assets ON assets.course_id = users.course_id
            WHERE users.canvas_course_role = 'urn:lti:role:ims/lis/Instructor'
              AND users.canvas_enrollment_state = 'active'
         GROUP BY users.id, users.course_id
         ORDER BY ARRAY_LENGTH(ARRAY_AGG(assets.id), 1) DESC
        """,
    )

    for row in busy_users:
        users.append({
            'user_id': row['user_id'],
            'course_id': row['course_id'],
        })


"""
TASKS
"""


class SquiggyTaskSet(TaskSet):

    def on_start(self):
        self.user.user_data = sample(TestData.users)
        self.load_front_end()
        self.login()

    def on_stop(self):
        self.logout()

    def load_front_end(self):
        html_response = self.client.get('/login')
        pq = PyQuery(html_response.content)
        asset_paths = []
        asset_paths += [e.attrib.get('href') for e in pq('link')]
        asset_paths += [e.attrib.get('src') for e in pq('script')]
        for path in asset_paths:
            if path:
                self.client.get(path)

    def login(self, user_id=None):
        if user_id is None:
            user_id = self.user.user_data['user_id']
        self.client.post(
            '/api/auth/dev_auth_login',
            json={
                'userId': user_id,
                'password': squiggy_cfg['dev_auth_password'],
            },
        )

    def logout(self):
        self.client.get('/api/auth/logout')

    @task(1)
    def load_asset_list(self):
        self.client.post(
            '/api/assets',
            json={'orderBy': 'recent'},
        )

    @task(2)
    def load_search_params(self):
        self.client.get(
            f"/api/course/{self.user.user_data['course_id']}/advanced_asset_search_options",
            name='/api/course/[course_id]/advanced_asset_search_options',
        )

    @task(3)
    def load_leaderboard(self):
        self.client.get('/api/users/leaderboard')


"""
LET THE LOCUSTS BE FREE!
"""


class SquiggyUser(HttpUser):
    tasks = [SquiggyTaskSet]
    host = squiggy_cfg['base_url']
    wait_time = between(1, 3)
    user_data = {}

    def __init__(self, parent):
        super().__init__(parent)
