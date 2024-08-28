#!/usr/bin/env python

import requests
import json
import os
import io
import urllib

from requests.auth import HTTPBasicAuth

requests.packages.urllib3.disable_warnings()

# DIT Details
dit_url = "https://atvdit.athtem.eei.ericsson.se/"
dit_doc = "api/documents"
dit_schema = "api/schemas"
dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"
headers = {"Content-Type": "application/json"}

# CI Portal(Axis)
ci_productSet_contents_url = "http://ci-portal.seli.wh.rnd.internal.ericsson.com/getProductSetVersionContents/?"
ci_iso_contents_url = "http://ci-portal.seli.wh.rnd.internal.ericsson.com/getPackagesInISO/?"


class Sed:
    def __init__(self, sed_id, schema_id):
        self.sed_id = sed_id
        self.schema_id = schema_id


def get_schema_version(prod_set_version):
    """
    Get the Schema Version for the particular product set.

    :param prod_set_version: version of the product set.
    """
    try:
        global enm_version
        enm_artifact_id = "ERICenm_CXP9027091"
        prodset_content_data = get_productset_contents(prod_set_version)
        enm_version = parse_for_iso_version(prodset_content_data, enm_artifact_id)
        iso_content_data = get_iso_contents(enm_version)
        enmcloudtemplates_version = parse_for_rpm_version("ERICenmcloudtemplates_CXP9033639", iso_content_data)
        print 'Schema Version:' + enmcloudtemplates_version
        return enmcloudtemplates_version
    except Exception as ex:
        raise Exception("Cannot get the Schema Version", ex)

def get_vnf_schema_version(prod_set_version):
    """
    Get the VNFLCM Schema Version for the particular product set.

    :param prod_set_version: version of the product set.
    """
    try:
        global vnf_version
        vnf_artifact_id = "ERICvnflcm_CXP9034858"
        prodset_content_data = get_productset_contents(prod_set_version)
        vnf_version = parse_for_iso_version(prodset_content_data, vnf_artifact_id)
        print 'VNFLCM Schema Version:' + vnf_version
        return vnf_version
    except Exception as ex:
        raise Exception("Cannot get the VNFLCM Schema Version", ex)

def update_schema_in_sed(sed_name, schema_version):
    """
    Update the Schema Version for the specified SED.

    :param sed_name: name of the SED
    :param schema_version: version of the schema
    """
    try:
        sed = get_sed_details_from_name(sed_name)
        if sed_name.startswith("VNFLCM"):
            schema_id = get_schema_id_from_name("vnflcm_sed_schema", schema_version)
        else:
            schema_id = get_schema_id_from_name("enm_sed", schema_version)
        if sed.schema_id == schema_id:
            print 'Sed ' + sed_name + ' is already updated with Schema Version ' + schema_version
            return
        full_url = dit_url + dit_doc + '/' + sed.sed_id
        json_data = json.dumps({"schema_id": schema_id})
        response = requests.put(full_url, data=json_data, headers=headers, auth=('METEOTOOL', 'DppvaPYdnCTwGKBRRf3PaqFS'))
        if response.status_code != 200:
            raise Exception("Schema ID cannot be updated")
        print sed_name + ' Updated with Schema Version:' + schema_version
    except Exception as ex:
        raise Exception("Cannot Update the Schema Version", ex)


def get_schema_id_from_name(schema_name, schema_version):
    """
    Get the schema id for the schema name

    :param schema_name: name of the schema to be fetched
    :param schema_version: version of the schema to be fetched.
    :return schema_id: id of the Schema file
    """
    try:
        amp = urllib.quote("&")
        query = '?q=name='+schema_name+amp+'version='+schema_version+'&fields=_id'
        schema_id_api_url = dit_url + dit_schema + query
        print 'Get Schema ID from DIT:' + schema_id_api_url
        response = requests.get(schema_id_api_url, headers=headers, auth=(dit_username, dit_password))
        if response.status_code != 200:
            raise Exception("Schema ID cannot be Obtained")
        schema_content = response.json()
        print 'Schema ID for schema_version ' + schema_version + ':' + schema_content[0]['_id']
        return schema_content[0]['_id']
    except Exception as ex:
        raise Exception("Cannot get the Schema id for the schema version:" + schema_version, ex)


def get_sed_details_from_name(sed_name):
    """
    Get the sed id for the sed name

    :param sed_name: name of the sed file to be downloaded.
    :return sed_id: id of the SED file
    """
    sed_api_url = dit_url + dit_doc + '?q=name=' + sed_name + '&fields=_id&fields=schema_id'
    print 'Get SED Details:' + sed_api_url
    try:
        response = requests.get(sed_api_url, headers=headers, auth=(dit_username, dit_password))
        if response.status_code != 200:
            raise Exception("SED Info cannot be Obtained")
        sed_content = response.json()
        print 'SED id:' + sed_content[0]['_id']
        print 'Schema id:' + sed_content[0]['schema_id']
        return Sed(sed_content[0]['_id'], sed_content[0]['schema_id'])
    except Exception as ex:
        raise Exception("Cannot get the SED id for the sed:" + sed_name, ex)


def download_sed_from_dit(sed_name, vnfsed_name):
    """
    Download the SED file from DIT

    :param sed_name: name of the sed file to be downloaded.
    """
    print "Download SED from DIT:" + dit_url + dit_doc + '?q=name=' + sed_name
    try:
        file_path = "seds"
        if not os.path.exists(file_path):
            os.makedirs(file_path)
        response = requests.get(dit_url + dit_doc + '?q=name=' + sed_name, headers=headers, auth=(dit_username, dit_password))
        if response.status_code != 200:
            raise Exception("SED cannot be downloaded")
        sed_content = response.json()
        #print sed_content[0]['content']
        with open(file_path+"/"+sed_name+"_sed.json", 'w') as f:
            f.write(json.dumps(sed_content[0]['content']))
        response = requests.get(dit_url + dit_doc + '?q=name=' + vnfsed_name, headers=headers, auth=(dit_username, dit_password))
        if response.status_code != 200:
            raise Exception("VNF SED cannot be downloaded")
        vnfsed_content = response.json()
        #print vnfsed_content[0]['content']
        with open(file_path+"/"+sed_name+"_vnfsed.json", 'w') as f:
            f.write(json.dumps(vnfsed_content[0]['content']))
    except Exception as ex:
        raise Exception("Cannot Download the SED", ex)
		

# Internal Functions
def get_productset_contents(prod_set_version):
    url_parameters = {"productSet": "ENM", "version": prod_set_version}
    url = urllib.urlencode(url_parameters)
    print 'Get ProductSet Contents: ' + ci_productSet_contents_url + url
    response = requests.get(ci_productSet_contents_url + url)
    # print response.content
    if response.status_code != 200:
        raise Exception("Product Set contents cannot be downloaded")
    return response.json()


def get_iso_contents(iso_version):
    url_parameters = {"isoName": "ERICenm_CXP9027091", "isoVersion": iso_version,
                      "pretty": "true"}
    url = urllib.urlencode(url_parameters)
    print 'Get ISO Contents: ' + ci_iso_contents_url + url
    response = requests.get(ci_iso_contents_url + url)
    # print response.content
    if response.status_code != 200:
        raise Exception("ISO contents cannot be downloaded")
    return response.json()


def parse_for_iso_version(json_returned, artifact_id):
    """
    :param json_returned:
    :param artifact_id:
    :return iso_version:
    This function loops through the parsed JSON string
    and returns the required iso_version.
    """
    if type(json_returned) is dict:
        for key_found in json_returned:
            if key_found == "artifactName":
                if json_returned[key_found] == artifact_id:
                    return json_returned["version"]
            iso_version = parse_for_iso_version(json_returned[key_found],
                                                artifact_id)
            if iso_version:
                return iso_version
    elif type(json_returned) is list:
        for item in json_returned:
            if type(item) in (list, dict):
                iso_version = parse_for_iso_version(item, artifact_id)
                if iso_version:
                    return iso_version


def parse_for_rpm_version(rpm_name, iso_content_data):
    json_object = iso_content_data
    if type(json_object) is dict:
        for key_found in json_object:
            if key_found == "PackagesInISO":
                iso_content = json_object[key_found]
                for package in iso_content:
                    if rpm_name in package['name']:
                        version = package['version']
                        pkgUrl = package['url']
                        return version


try:
    deploymentId=os.environ['deploymentId']
    vnfsed_name="VNFLCM_"+deploymentId
    print "Deployment: " + os.environ['deploymentId']
    product_set_version=os.environ['product_set_version']
    schema_version=get_schema_version(product_set_version)
    vnf_schema_version=get_vnf_schema_version(product_set_version)
    update_schema_in_sed(deploymentId, schema_version)
    update_schema_in_sed(vnfsed_name, vnf_schema_version)
    download_sed_from_dit(deploymentId, vnfsed_name)
    print ""
except Exception as e:
    print e
    exit(1)

