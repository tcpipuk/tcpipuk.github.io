# Deploying a Synapse Homeserver with Docker

## Introduction

Welcome to my deployment guide for setting up a Matrix Synapse Homeserver using Docker. Our setup focuses on scalability and efficiency, using multiple "workers" to distribute workload and enhance performance.

Synapse, as the reference homeserver implementation for the Matrix network, offers flexible and decentralised communication capabilities, including messaging, voice calls, and custom integrations.

In a closed system, it performs exceptionally well on default settings, allowing many users to communicate in thousands of chats. However, when opening up to the internet to join public rooms, it can struggle to manage communicating with hundreds/thousands of other servers at the speed you'd expect from an instant communication platform.

There is a default model described in the [official documentation](https://matrix-org.github.io/synapse/latest/workers.html), but this design is optimised for a family or team of users to access federated rooms at high speed without using so much extra CPU and RAM.

## Workers

In this deployment, we use a variety of Synapse workers, each with a specific role.

We want to give each worker plenty of work to do, so it's not just sitting around using memory for no reason, but also make sure we're not overwhelming individual workers in ways that impact the service.

Here's a list of what we're prescribing to start:

- **Client Sync Worker**: Fast delivery of messages and other updates to client devices. In this deployment, also responsible for managing user presence, typing notifications, and read receipts, so the data is available right where you need it.
- **Federation Reader**: Process incoming federation updates from other Matrix servers, and answers any requests from other servers that don't specify a room ID.
- **Federation Senders (4 instances)**: Send out events and messages to other servers in the Matrix federation, distributing the workload to keep up with even the largest rooms.
- **Media Workers**: Dedicated to handling media uploads and downloads, including generating thumbnails for images, and running any media maintenance jobs.
- **Room Workers (4 instances)**: Receive all requests for room data from both clients and federation, balanced by room ID to keep all cache for one room efficiently in one place.
- **Background Worker**: Perform background tasks like database maintenance, push notifications, and periodic tasks. In this deployment, also responsible for receiving new events and writing them into the database.

## Getting Started

To get your Synapse Homeserver up and running, follow the configuration guides for each component. The end result should be a powerful, self-hosted communication platform. And as always, if questions pop up or you hit a snag, the [Synapse Admins](https://matrix.to/#/#synapse:matrix.org) room is there to lend a hand.
