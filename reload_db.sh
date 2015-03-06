#!/bin/sh

MIX_ENV=dev mix ecto.drop
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate