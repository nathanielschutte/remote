# remote
 Library of deploy and other remote functions

## Function
### Project deploy
- configure project: maintain remote info and file mapping
- deploy project: using configured remotes or manual
- remote script execute: maintain and execute start/stop (or other) scripts on remote
### File deploy
- deploy files: using profile or manual
### Extra
- configure profiles: maintain remote info to be used for project remote hosts or file deploys

## Usage
### Initialize
- Initialize current directory as a project (optionally use profile for remote info)
```
remote init
```
### Configure project
- Add project remote deploy info
```
remote add <tag>
    -h|--host <host>
    -p|--port <port> 
    -u|--user <remote-user> 
    -i|--key <key-file> 
    -l|--local-path <local-path> (defaults to current dir)
    -o|--remote-path <remote-path>

remote add <tag> --profile <profile> [ -o <remote-path> ... ]

remote add <tag> --copy <existing remote tag>
```
- Edit project remote deploy info
```
remote edit <tag>
    -h|--host <host>
    -p|--port <port>
    ...
```
- Set mapping, exclude files, dirs, additional config options for each tagged remote
- Set active remote tag
```
remote use <tag>
```
- Get info about the current configured remotes, or details on a specific tagged remote
```
remote info [ <tag> ]
```
### Deploy project
- Deploy project to configured remote
```
remote deploy
```
- Deploy project
```
remote deploy -P <profile> -r <remote-path>
```
### Deploy files
- Deploy files
```
remote deploy -f <files...> -w <user@host:port/remote-path>
remote deploy -f <files...> -P <profile> -o <remote-path>
remote deploy -f <files...> -h <host> -p <port> -u <user> -i <key-file> -o <remote-path>
```
- Deploy directories recursively using --recursive | -r
