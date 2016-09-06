### Get script help
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -h
```
### Install rabbitmq (default node type: disk)
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -i
```
### Install rabbitmq with erlang cookie
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -i -c ZTXOCZYZWBCFLBPOBEUQ
```
### Install rabbitmq & Set node type to ram
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -i -n ram
```
### Install & Join rabbitmq cluster
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -ij rabbitmq-master
```
### Uninstall rabbitmq
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -e
```
### Update rabbitmq
```bash
# sh ./install-rabbitmq/install_rabbitmq.sh -u
```