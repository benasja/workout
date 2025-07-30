#!/bin/bash

# Generate live project statistics
echo "# 📊 Live Project Statistics"
echo ""
echo "**Last Updated:** $(date)"
echo ""

# Lines of code
echo "## Code Statistics"
echo "- **Total Lines:** $(find . -name '*.swift' -exec wc -l {} + | tail -1 | awk '{print $1}')"
echo "- **Swift Files:** $(find . -name '*.swift' | wc -l)"
echo "- **Test Files:** $(find . -name '*Tests.swift' | wc -l)"
echo ""

# Git statistics
echo "## Git Statistics"
echo "- **Total Commits:** $(git rev-list --all --count)"
echo "- **Contributors:** $(git shortlog -sn | wc -l)"
echo "- **Branches:** $(git branch -r | wc -l)"
echo "- **Last Commit:** $(git log -1 --format=%cd --date=relative)"
echo ""

# File breakdown
echo "## File Breakdown"
echo "- **Models:** $(find work/Models -name '*.swift' | wc -l) files"
echo "- **Views:** $(find work/Views -name '*.swift' | wc -l) files"
echo "- **ViewModels:** $(find work/ViewModels -name '*.swift' | wc -l) files"
echo "- **Utils:** $(find work/Utils -name '*.swift' | wc -l) files"
echo "- **Tests:** $(find workTests -name '*.swift' | wc -l) files"