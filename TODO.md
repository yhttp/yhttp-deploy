## task1
- [x] update bundle.sh and do not copy public directory if it's empty

## task2
- [x] implement new option named `nginx-configentry` which can be specified
  multiple times. it means the underlaying variable must be an array.
- [x] store the nginx config entries provided by user into the .vars file
  after bundle.sh:281.
- [x] use these entries in the target-install.sh and write them while
  generating the nginx configuration for the virtual host inside the ssl
  virtual host.

## task3
- [] check subdomain and SSL
