#!/usr/bin/env bash
# @file backup_figma_config.sh
# Figma back up settings and preferences
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

# The Team ID and Project ID is in the Project URL, e.g.
# https://www.figma.com/files/<TEAM_ID>/team/<PROJECT_ID>

# Figma Team identities ---------------------------------------------------
# shellcheck disable=SC2034
FIGMA_TEAMS=(
    "AllSpark_UI"
    "Aria Hub"
    "CSP"
    "DesignOps"
    "EPKS"
    "MAPBU"
    "MAPBU Design"
    "Tanzu Application Platform"
    "Tanzu Mission Control"
    "VMC"
    "Warefront"
)
FIGMA_TEAM_IDS=(
    "621934090331229514"
    "1179914499920505579"
    "650110695027218490"
    "650397983853728437"
    "833071938601060726"
    "799770132655174581"
    "953431714079045697"
    "913468582173749571"
    "725065623170155494"
    "664204467040999021"
    "721148728153361126"
)