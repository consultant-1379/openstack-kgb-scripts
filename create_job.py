import os
from xml.sax.saxutils import escape
import requests

jenkins_url = os.environ.get('JENKINS_URL')
kgb_job_url = os.environ.get('KGB_TEMPLATE')
quarantine_job_url = os.environ.get('QUARANTINE_TEMPLATE')
team_name = os.environ.get('TEAM_NAME')


def get_values_to_replace():
    return {
        '__TEAM_NAME__': team_name,
        '__XML_SCHEDULE__': escape(os.environ.get('XML_SCHEDULE'))
    }


def replace_values_in_xml(response):
    for key, value in get_values_to_replace().iteritems():
        response = response.replace(key, value)
    return response


def get_template_config_xml(job_url):
    response = requests.get(job_url + 'config.xml')
    if response.status_code != 200:
        response.raise_for_status()
    updated_config = replace_values_in_xml(response.content)
    create_new_job(updated_config, job_url.rsplit('_', 1)[1][:-1])


def create_new_job(xml_string, job_type):
    job_name = 'Team_{0}_{1}'.format(team_name, job_type)
    url = jenkins_url + 'createItem?name={0}'.format(job_name)
    headers = {'Content-Type': 'application/xml'}
    auth = ('enmadm100', 'bdb128547862518241edd91ef42aa151')
    response = requests.post(url, auth=auth, data=xml_string, headers=headers)
    if response.status_code != 200:
        response.raise_for_status()
    print 'Job Created - {0}job/{1}'.format(jenkins_url, job_name)

if __name__ == "__main__":
    get_template_config_xml(kgb_job_url)
    get_template_config_xml(quarantine_job_url)
