## yd1 - workers
- the `workers` environment variable is a bash array and may contains zero or 
  more shell command to be deployed as a systemd service.
- edit the `target-install.sh`
- loop over this array and create a systemd sercice unit for each.
- create all units inside the `systemd_dir` envronment variable.
- set the `Requires`, `After` and `BindsTo` options to `systemd_unit` env 
  variable.
