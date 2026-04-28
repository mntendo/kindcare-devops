#!/bin/bash
set -e

echo "=== STEP 6: Notify ==="

echo "Deployment Summary:"
echo "  Environment : $ENVIRONMENT"
echo "  Image Tag   : $IMAGE_TAG"
echo "  Status      : SUCCESS"
echo "  Time        : $(date)"

echo "=== Done ==="
