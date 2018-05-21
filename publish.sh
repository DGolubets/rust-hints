#!/bin/sh
BRANCH=$(git rev-parse --abbrev-ref HEAD)
mdbook clean
mdbook build
git checkout -B build
git add book -f
git commit -m "Book dist"
git subtree split --prefix book -b gh-pages
git push -f origin gh-pages:gh-pages
git checkout $BRANCH
git branch -D build gh-pages