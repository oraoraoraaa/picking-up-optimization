# Picking-Up Optimization

A tool for optimizing the process of a driver picking up a passenger.

## Problem

When a driver is on the way to pick someone up, traffic congestion near the pickup location can cause significant delays. Simply waiting for the driver to navigate through the jam wastes time for both parties.

## Solution

This software analyzes real-time traffic conditions around the passenger's current location. If heavy traffic is detected nearby, it suggests alternative meeting points that the passenger can reach on foot or by public transit. By moving the pickup location out of the congested area, the overall pickup time is reduced for both the driver and the passenger.

## Features

- Real-time traffic congestion detection around the pickup point
- Alternative pickup point suggestions based on walking or transit options
- Route estimation for both the driver and the passenger

## API

This project uses the [Amap (高德地图) API](https://lbs.amap.com/) for map data, real-time traffic information, and route planning.
