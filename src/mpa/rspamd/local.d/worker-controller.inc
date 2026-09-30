# Web UI and learning endpoints, proxied by nginx at /.
bind_socket = "0.0.0.0:11334";
count = 1;
password = "{= env.password =}";
enable_password = "{= env.password =}";
