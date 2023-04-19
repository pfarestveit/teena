"""
BOA load test script for use with the Locust tool (https://locust.io).

Usage:

From the top-level Teena directory, install dependencies.
pip -r requirements.txt

Start Locust with this file.
locust -f load_tests/boa_locust.py

In your browser, go to localhost:8089 to start tests and view charts.

Visit https://locust.io for more information.
"""


from itertools import groupby
import os
import random
import yaml

from locust import HttpLocust, TaskSet, task
import psycopg2
import psycopg2.extras
from pyquery import PyQuery


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


boac_cfg = configs['boac']
nessie_cfg = configs['nessie']


"""
Define database connections.
"""


class Rds():
    @classmethod
    def fetch(cls, sql, params=None):
        connection = psycopg2.connect(**cls.connection_params)
        cursor = connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute(sql, params)
        results = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        connection.close()
        return results


class BoaRds(Rds):
    connection_params = {
        'dbname': boac_cfg['db_name'],
        'user': boac_cfg['db_user'],
        'password': boac_cfg['db_password'],
        'host': boac_cfg['db_host'],
        'port': boac_cfg['db_port'],
    }


class NessieRds(Rds):
    connection_params = {
        'dbname': nessie_cfg['pg_db_name'],
        'user': nessie_cfg['pg_db_user'],
        'password': nessie_cfg['pg_db_password'],
        'host': nessie_cfg['pg_db_host'],
        'port': nessie_cfg['pg_db_port'],
    }


"""
Load test data.
"""


def _row_to_note_draft(row):
    return {
        'id': row['note_id'],
        'subject': row['subject'],
        'body': row['body'],
        'sid': row['sid'],
    }


def _row_to_cohort(row):
    return {
        'id': row['cohort_id'],
        'student_count': row['student_count'],
        'filter_criteria': row['filter_criteria'],
    }


class TestData:

    students = NessieRds.fetch(f"""
        SELECT sid, uid FROM student.student_profile_index
        ORDER BY last_name
        OFFSET {random.randint(0,30000)}
        LIMIT 50
    """)

    search_phrases = ['meet', 'Angh', 'Sandeep', 'June', 'Math', 'Appointment', 'PUB', ',', 'History']

    users = []
    user_draft_note_results = BoaRds.fetch("""
        SELECT au.uid AS uid, notes.id AS note_id, notes.body, notes.subject, notes.sid
        FROM authorized_users au
        JOIN notes on notes.author_uid = au.uid
        WHERE au.deleted_at IS NULL
        AND au.can_access_canvas_data IS TRUE
        AND notes.is_draft IS TRUE
        AND notes.deleted_at IS NULL"""
    )
    for uid, rows in groupby(user_draft_note_results, lambda x: x['uid']):
        users.append({
            'uid': uid,
            'note_drafts': [_row_to_note_draft(r) for r in rows],
        })

    cohort_users = []
    uids = ''
    for i in [u['uid'] for u in users]:
        uids += f'\'{i}\', '
    user_cohort_results = BoaRds.fetch(f"""
        SELECT au.uid AS uid, cf.id AS cohort_id, cf.student_count, cf.filter_criteria
        FROM authorized_users au
        JOIN cohort_filters cf on cf.owner_id = au.id
        WHERE au.deleted_at IS NULL
        AND au.uid IN ({uids[:-2]})
        ORDER BY uid"""
    )
    for uid, rows in groupby(user_cohort_results, lambda x: x['uid']):
        cohort_users.append({
            'uid': uid,
            'cohorts': [_row_to_cohort(r) for r in rows],
        })

    for u in users:
        for c in cohort_users:
            if u['uid'] == c['uid']:
                u.update(c)


"""
Define user tasks.
"""


class BoaTaskSet(TaskSet):

    def on_start(self):
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

    def login(self, uid=None):
        if uid is None:
            uid = self.locust.user['uid']
        print(f"Test UID {uid}")
        self.client.post(
            '/api/auth/dev_auth_login',
            json={
                'uid': uid,
                'password': boac_cfg['password'],
            },
        )

    def logout(self):
        self.client.get('/api/auth/logout')

    @task(1)
    def load_home_page(self):
        self.client.get('/api/cohorts/all')
        self.client.get('/api/curated_groups/all')
        self.client.get('/api/service_announcement')
        self.client.get('/api/note_templates/my')
        self.client.get('/api/topics/all?includeDeleted=false')
        self.client.get('/api/notes/my_drafts')

    @task(2)
    def search(self):
        self.client.post(
            '/api/search',
            json={
                'searchPhrase': sample(TestData.search_phrases),
                'students': 'True',
                'courses': 'True',
                'notes': 'True',
            },
        )

    @task(3)
    def load_cohort_page(self):
        try:
            cohort = sample(self.locust.user['cohorts'])
            self.client.get(f"/api/cohort/{cohort['id']}", name='/api/cohort/[id]')
            self.client.post('/api/cohort/filter_options/me', json={'existingFilters': []})
            self.client.post('/api/cohort/translate_to_filter_options/me', json={'filterCriteria': cohort['filter_criteria']})
        except: KeyError

    @task(4)
    def load_student_page(self):
        student = sample(TestData.students)
        self.client.get(f"/api/student/by_uid/{student['uid']}", name='/api/student/by_uid/[uid]')

    @task(5)
    def update_drafts(self):
        note = sample(self.locust.user['note_drafts'])
        self.client.post(
            '/api/notes/update',
            data={
                'id': str(note['id']),
                'body': (note['body'] or ''),
                'cohortIds': [],
                'curatedGroupIds': [],
                'isDraft': 'True',
                'isPrivate': 'False',
                'sids': (note['sid'] or ''),
                'subject': (note['subject'] or ''),
            },
            files={},
        )


"""
Hatch a locust.
"""


class BoaLocust(HttpLocust):
    task_set = BoaTaskSet
    host = boac_cfg['api_base_url']
    min_wait = 1000
    max_wait = 3000

    def __init__(self):
        super(BoaLocust, self).__init__()
        self.user = sample(TestData.users)
