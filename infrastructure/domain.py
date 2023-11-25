# --------------------------------------------------------------------------------------------------#
# This script deals with the Route53 to perform the following:                                      #
#     1. Create a Route53 hosted zone if it does not exist for the domain                           #                                                                              #
#     2. Identifies the Name servers from NS records from the hosted zone                           #
#     4. Update the Name servers in the domain registrar, if required                               #
#     2. Creates an Alias (A) record in the hosted zone to point the Public IP of the               #
#        EC2 instance                                                                               #
#                                                                                                   #
#  Assumption:                                                                                      #
#     Prior to running this script, the domain name should be registered with AWS Route53           #
#     Domain Registrar and the domain name should be visible in the "Registered domains" section    #
#     of the Route53 console.                                                                       #
#                                                                                                   #
# --------------------------------------------------------------------------------------------------#
import boto3
import argparse
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: [@ %(filename)s:%(lineno)d] ==> %(message)s",
)
logger = logging.getLogger(__name__)


def flatten_json(json_doc):
    out = {}

    def flatten(x, name=""):
        if type(x) is dict:
            for a in x:
                flatten(x[a], name + a + ".")
        elif type(x) is list:
            i = 0
            for a in x:
                flatten(a, name + str(i) + ".")
                i += 1
        else:
            out[name[:-1]] = x

    flatten(json_doc)
    return out


def print_dict(d: dict) -> None:
    """
    Prints a dictionary
    """
    for k, v in d.items():
        logger.debug("{}: {}".format(k, v))


def check_hosted_zone(domain_name: str) -> bool:
    """Check if the hosted zone exists in Route53"""
    client = boto3.client("route53")
    response = client.list_hosted_zones_by_name(DNSName=domain_name)

    print_dict(flatten_json(response))

    zone_found = False
    zone_id = None

    for zone in response["HostedZones"]:
        if zone["Name"][:-1] == domain_name:
            zone_found = True
            zone_id = zone["Id"]

    return (zone_found, zone_id)


def create_hosted_zone(domain_name: str) -> str:
    """Create a hosted zone in Route53"""
    client = boto3.client("route53")
    response = client.create_hosted_zone(Name=domain_name, CallerReference="string")

    print_dict(flatten_json(response))

    return response["HostedZone"]["Id"]


def get_hosted_zone_id(domain_name: str) -> str:
    """Get the hosted zone id"""
    client = boto3.client("route53")
    response = client.list_hosted_zones_by_name(DNSName=domain_name)
    print_dict(flatten_json(response))

    return response["HostedZones"][0]["Id"]


def get_hosted_zone_name_servers(hosted_zone_id: str) -> list:
    """Get the name servers from the hosted zone"""
    client = boto3.client("route53")
    response = client.get_hosted_zone(Id=hosted_zone_id)
    print_dict(flatten_json(response))
    return response["DelegationSet"]["NameServers"]


def get_domain_registrar_name_servers(domain_name: str) -> list:
    """Get the name servers from the domain registrar"""
    client = boto3.client("route53domains", region_name="us-east-1")
    response = client.get_domain_detail(DomainName=domain_name)
    print_dict(flatten_json(response))
    return response["Nameservers"]


def create_alias_record(domain_name: str, public_ip: str) -> str:
    """
    Create Alias record in Hosted Zone
    """
    try:
        client = boto3.client("route53")
        hosted_zone_id_full = get_hosted_zone_id(domain_name)
        hosted_zone_id = hosted_zone_id_full.split("/")[-1]

        response = client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                "Comment": "Alias record for EC2 instance",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": domain_name,
                            "Type": "A",
                            "TTL": 60,
                            "ResourceRecords": [
                                {
                                    "Value": public_ip,
                                },
                            ],
                        },
                    },
                ],
            },
        )

        print_dict(flatten_json(response))

        return response["ChangeInfo"]["Id"]

    except Exception as err:
        logger.error("Unable to create alias record in hosted zone")
        logger.error(err)
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process domain name")
    parser.add_argument("domain_name", type=str, help="domain name")
    parser.add_argument("public_ip", type=str, help="public ip of the ec2 instance")

    args = parser.parse_args()

    domain_name = args.domain_name
    public_ip = args.public_ip

    if domain_name is None:
        logger.error("Domain name is required")
        sys.exit(1)

    if public_ip is None:
        logger.error("Public IP is required")
        sys.exit(1)

    # Check if the hosted zone exists
    zone_flag, hosted_zone_id = check_hosted_zone(domain_name)

    if zone_flag:
        logger.info(f"Hosted zone already exists for domain {domain_name}")
        logger.info(f"Hosted zone id: {hosted_zone_id}")
    else:
        logger.info("Hosted zone does not exist yet for domain {domain_name}")
        hosted_zone_id = create_hosted_zone(domain_name)
        logger.info(f"Hosted zone created: {hosted_zone_id}")

    # Get name servers from hosted zone
    hosted_zone_name_servers = get_hosted_zone_name_servers(hosted_zone_id)
    logger.info(f"Hosted Zone Name servers: {hosted_zone_name_servers}")

    # Get name servers from domain registrar
    name_servers = get_domain_registrar_name_servers(domain_name)
    domain_registrar_name_servers = list()

    for ns in name_servers:
        domain_registrar_name_servers.append(ns["Name"])

    logger.info(f"Domain registrar name servers: {domain_registrar_name_servers}")

    # If Hosted zone name servers and domain registrar name servers are different,
    # update the domain registrar.
    if sorted(hosted_zone_name_servers) != sorted(domain_registrar_name_servers):
        logger.info("Updating domain registrar name servers ...")
        client = boto3.client("route53domains", region_name="us-east-1")

        response = client.update_domain_nameservers(
            DomainName=domain_name,
            Nameservers=[
                {"Name": hosted_zone_name_servers[0]},
                {"Name": hosted_zone_name_servers[1]},
                {"Name": hosted_zone_name_servers[2]},
                {"Name": hosted_zone_name_servers[3]},
            ],
        )
        logger.info("Domain registrar name servers updated")
    else:
        logger.info(
            "Domain registrar & hosted zone name servers are same. No update required!"
        )

    # Create alias record in hosted zone
    logger.info(f"Creating alias record in hosted zone using {domain_name} and {public_ip}")
    change_id = create_alias_record(domain_name, public_ip)
    logger.info(f"Change id: {change_id}")
    logger.info("Done!")

    sys.exit(0)
