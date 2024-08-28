#!/usr/bin/env python

import getopt
import json
import os
import re
import sys
import urllib
import urllib2
import base64

dit_username="METEOTOOL"
dit_password="DppvaPYdnCTwGKBRRf3PaqFS"


def main_get_info_from_args(argv):
    """
    Function to parse the parameters
    """
    product_set_version=os.environ['product_set_version']
    openstackdeploy_version = "none"
    openstackdeploy_version_lower = openstackdeploy_version.lower()
    if openstackdeploy_version_lower == "none":
        # Get the Version of the Openstack Deployer Attached to the Product Set
        dmt_url = ("https://ci-portal.seli.wh.rnd.internal.ericsson.com/api/deployment/"
                   "deploymentutilities/productSet/ENM/version/" +
                   str(product_set_version) + "/")
        deploymentUtilities = return_url_response(dmt_url)
        deploymentUtilitiesJson = return_json_object(deploymentUtilities)
        for key in deploymentUtilitiesJson:
            if key == "deployerVersion":
                openstackdeploy_version = deploymentUtilitiesJson[key]
                break

    start_functions(product_set_version, openstackdeploy_version)


def start_functions(product_set_version, openstackdeploy_version):
    """
    Main function to call script functions
    """

    enm_artifact_id = "ERICenm_CXP9027091"
    vnflcm_artifact_id = "ERICvnflcm_CXP9034858"
    edp_artifact_id = "ERICautodeploy_CXP9038326"
    agat_artifact_id = "ERICenmagat_CXP9036311"
    url_parameters = {"productSet": "ENM", "version": product_set_version}
    url = urllib.urlencode(url_parameters)
    dmt_url = ("http://ci-portal.seli.wh.rnd.internal.ericsson.com/"
               "getProductSetVersionContents/?" + url)
    html_response = return_url_response(dmt_url)
    product_set_content_json = return_json_object(html_response)
    enm_version = search_for_iso_version(product_set_content_json,
                                         enm_artifact_id)
    enm_url = search_for_iso_url(product_set_content_json, enm_artifact_id)
    vnflcm_url = search_for_iso_url(product_set_content_json,
                                    vnflcm_artifact_id)
    vnflcm_version = search_for_iso_version(product_set_content_json,
                                            vnflcm_artifact_id)
    edp_url = search_for_iso_url(product_set_content_json,
                                 edp_artifact_id)
    edp_version = search_for_iso_version(product_set_content_json,
                                         edp_artifact_id)
    agat_url = search_for_iso_url(product_set_content_json, agat_artifact_id)
    agat_version = search_for_iso_version(product_set_content_json,
                                          agat_artifact_id)

    iso_content_data = get_json_data(enm_artifact_id, enm_version)
    vnflcm_data = get_json_data(vnflcm_artifact_id, vnflcm_version)
    rhelvnflafimage = get_url_of_rpm("ERICrhelvnflafimage_CXP9032490",
                                     vnflcm_data)
    rhelpostgresimage = get_url_of_rpm("ERICrhelpostgresimage_CXP9032491",
                                       vnflcm_data)
    vnflcmcloudtemplatesimage = get_url_of_rpm("vnflcm-cloudtemplates",
                                               vnflcm_data)
    microenmcloudtemplates = get_url_of_rpm(
        "ERICmicroenmcloudtemplates_CXP9033953", iso_content_data)
    enmcloudtemplates = get_url_of_rpm("ERICenmcloudtemplates_CXP9033639",
                                       iso_content_data)
    enmdeploymentworkflows = get_url_of_rpm(
        "ERICenmdeploymentworkflows_CXP9034151", iso_content_data)

    rhelvnflafimage_version = get_version_of_rpm(
        "ERICrhelvnflafimage_CXP9032490", vnflcm_data)
    rhelpostgresimage_version = get_version_of_rpm(
        "ERICrhelpostgresimage_CXP9032491", vnflcm_data)
    vnflcmcloudtemplates_version = get_version_of_rpm("vnflcm-cloudtemplates",
                                                      vnflcm_data)
    microenmcloudtemplates_version = get_version_of_rpm(
        "ERICmicroenmcloudtemplates_CXP9033953", iso_content_data)
    enmcloudtemplates_version = get_version_of_rpm(
        "ERICenmcloudtemplates_CXP9033639", iso_content_data)
    enmdeploymentworkflows_version = get_version_of_rpm(
        "ERICenmdeploymentworkflows_CXP9034151", iso_content_data)
    enmcloudmgmtworkflows = get_url_of_rpm("ERICenmcloudmgmtworkflows_CXP9036442",
                                    iso_content_data)
    enmcloudperformanceworkflows = get_url_of_rpm("ERICenmcloudperformanceworkflows_CXP9037118",
                                    iso_content_data)


    enm_schema_version = get_version_of_rpm('ERICenmcloudtemplates_CXP9033639', iso_content_data)
    dit_url = 'https://atvdit.athtem.eei.ericsson.se'
    request = urllib2.Request(dit_url + '/api/documents?q=name=enm_media_mapping_' + enm_schema_version + '&fields=content')
    base64string = base64.b64encode('%s:%s' % (dit_username, dit_password))
    request.add_header("Authorization", "Basic %s" % base64string)
    request.add_header('Content-Type', 'application/json')

    dit_enm_media_response = return_url_response(request)
    dit_enm_media_json = return_json_object(dit_enm_media_response)
    enm_sed_media_mappings = dit_enm_media_json[0]['content']['parameters']
    enm_sed_media_mappings.pop('edp_autodeploy_media')

    enm_media_cxp_numbers = [
        cxp_number for sed_key, cxp_number in enm_sed_media_mappings.items()
        if sed_key.endswith('_media')]

    enm_media_types = {
        cxp_number: ('media' if cxp_number in enm_media_cxp_numbers else 'iso_content')
                     for cxp_number in enm_sed_media_mappings.values()}

    media_details = {}
    for cxp_number, media_type in enm_media_types.items():
        if media_type == 'iso_content':
            media_details.update(
                {cxp_number: get_url_of_rpm(cxp_number, iso_content_data)}
            )
        else:
            media_details.update(
                {cxp_number: search_for_iso_url(product_set_content_json[0], cxp_number)}
            )



    file = open("env.conf", "w+")
    for cxp_number, media_url in media_details.items():
         print cxp_number, media_url
         file.write(cxp_number + "_url=" + media_url + "\n")

    file.write("enmcloudtemplates_url="+enmcloudtemplates+"\n")
    file.write("enmcloudtemplates_version="+enmcloudtemplates_version+"\n")
    file.write("enmdeploymentworkflows_url="+enmdeploymentworkflows+"\n")
    file.write("enmdeploymentworkflows_version="+enmdeploymentworkflows_version+"\n")
    file.write("rhelpostgresimage_url="+rhelpostgresimage+"\n")
    file.write("rhelpostgresimage_version="+rhelpostgresimage_version+"\n")
    file.write("vnflcm_url="+vnflcm_url+"\n")
    file.write("vnflafimage_version="+vnflcm_version+"\n")
    file.write("rhelvnflafimage_url="+rhelvnflafimage+"\n")
    file.write("rhelvnflafimage_version="+rhelvnflafimage_version+"\n")
    file.write("vnflcmcloudtemplatesimage_url="+vnflcmcloudtemplatesimage+"\n")
    file.write("vnflcmcloudtemplates_version="+vnflcmcloudtemplates_version+"\n")
    file.write("enmcloudmgmtworkflows_url="+enmcloudmgmtworkflows+"\n")
    file.write("enmcloudperformanceworkflows_url="+enmcloudperformanceworkflows+"\n")
    file.write("edp_autodeploy_url="+edp_url+"\n")
    file.write("edp_autodeploy_version="+edp_version+"\n")
    file.close()


    media = {
        "media_details": {
            "CXP9032491": "",
            "CXP9032490": ""

        },
        "cloud_templates_details": {
            "CXP9033639": ""
        },
        "deployment_workflows_details": {
            "CXP9034151": ""
        },
        "cloud_mgmt_workflows_details":{
            "CXP9036442":""
        },
        "cloud_performance_workflows_details":{
            "CXP9037118":""
        },
        "vnflcm_cloudtemplates_details": {
            "vnflcm-cloudtemplates": ""
        },
        "vnflcm_details":{
            "CXP9034858":""
        },
        "edp_autodeploy_details": {
            "CXP9038326": ""
        }
    }
    media['media_details'].update(media_details)

    with open('env.conf','r') as f:
        media_files = f.readlines()
    for k, v in media.items():
        for cxp, file_location in v.items():
            for media_file in media_files:
                if cxp in media_file.split('=')[1]:
                    media[k][cxp]=media_file.split('=')[1].rstrip()
    with open("media_urls.json", 'w+') as outfile:
        json.dump(media, outfile)

def search_for_iso_version(json_returned, artifact_id):
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
            iso_version = search_for_iso_version(json_returned[key_found],
                                                 artifact_id)
            if iso_version:
                return iso_version
    elif type(json_returned) is list:
        for item in json_returned:
            if type(item) in (list, dict):
                iso_version = search_for_iso_version(item, artifact_id)
                if iso_version:
                    return iso_version


def search_for_iso_url(json_returned, artifact_id):
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
                if artifact_id in json_returned[key_found]:
                    # If statement can be removed once CIS-72810 is closed
                    # (leave athloneUrl)
                    if json_returned.get("athloneUrl"):
                        return json_returned["athloneUrl"]
                    else:
                        return json_returned["hubUrl"]

            iso_version = search_for_iso_url(json_returned[key_found],
                                             artifact_id)
            if iso_version:
                return iso_version
    elif type(json_returned) is list:
        for item in json_returned:
            if type(item) in (list, dict):
                iso_version = search_for_iso_url(item, artifact_id)
                if iso_version:
                    return iso_version


def return_json_object(html_response):
    try:
        parsed_json = json.loads(html_response)
    except ValueError:
        return False
    return parsed_json


def return_url_response(url):
    try:
        response = urllib2.urlopen(url)
    except urllib2.HTTPError, e:
        return False
    except urllib2.URLError, e:
        return False
    except ValueError, response:

        return False
    except socket.error as err:
        return False
    html_response = response.read()
    return html_response


def get_json_data(artifact_id, iso_version):
    url_parameters = {"isoName": artifact_id, "isoVersion": iso_version,
                      "pretty": "true"}
    url = urllib.urlencode(url_parameters)
    iso_content_rest_call = ("http://ci-portal.seli.wh.rnd.internal.ericsson.com/"
                             "getPackagesInISO/?" + url + "&useLocalNexus=true")
    iso_content_html_response = return_url_response(
        iso_content_rest_call)
    iso_content_data = return_json_object(
        iso_content_html_response)

    return iso_content_data


def get_version_of_rpm(rpm_name, iso_content_data):
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


def get_url_of_rpm(rpm_name, iso_content_data):
    json_object = iso_content_data
    if type(json_object) is dict:
        for key_found in json_object:
            if key_found == "PackagesInISO":
                iso_content = json_object[key_found]
                for package in iso_content:
                    if rpm_name in package['name']:
                        version = package['version']
                        if package.get('localNexusUrl'):
                            return package['localNexusUrl']
                        return package['url']


if __name__ == "__main__":
    main_get_info_from_args(sys.argv[1:])
