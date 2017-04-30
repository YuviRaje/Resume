#!/bin/sh

# print octal mode for a file

if [ $# -ne 1 ]; then
    echo "Usage: `basename $0` path" >&2
    exit 1
fi

stat $1 | sed -n 's/^Access: (\([0-9]\{1,\}\).*/\1/p'