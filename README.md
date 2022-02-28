# remote
 library of deploy and other remote functions

## Function
- configure project: maintain remote info and file mapping
- configure profiles: maintain remote info
- deploy project: use project configuration
- deploy list of files: specifiy remote info or use a profile
- remote stop/start: execute start/stop scripts on remote

## Usage
### Initialize
- Initialize current directory as a project (optionally use profile for remote info)
```
remote init [ -p|--profile <profile-name> ]
```
### Configure project
- Add project remote deploy info
```
remote add <tag>
    -h|--host <host>
    -p|--port <port> 
    -u|--user <remote-user> 
    -i|--key <key-file> 
    -l|--local-path <local-path> (defaults to .)
    -r|--remote-path <remote-path>

remote add <tag> --profile <profile> -r <remote-path>

remote add <tag> --copy <existing remote tag>
```
- Edit project remote deploy info
```
remote edit <tag>
    -h|--host <host>
    -p|--port <port> 
    ...
```
- Set active remote tag
```
remote use <tag>
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
remote deploy -f <files...> -P <profile> -r <remote-path>
remote deploy -f <files...> -h <host> -p <port> -u <user> -i <key-file> -r <remote-path>
```
