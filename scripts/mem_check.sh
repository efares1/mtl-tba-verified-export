#!/bin/bash
free -m | head -2
ps -eo pid,etime,rss,args --sort=-rss | head -6 | cut -c1-140
