import re
with open(MediaExtractor.m, r, encoding=utf-8) as f:
    content = f.read()

# Replace isStrictVideoURL checks
content = content.replace(
