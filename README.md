# Description

This repo will demonstrate running a local Nomad cluster in -dev mode.

The Nomad version used in this configuration is `Nomad v1.1.3`

We will run two [nomad jobs](https://www.nomadproject.io/docs/job-specification)
 - **[Consul](https://www.consul.io/):**
  - **consul.nomad** will be used for service discovery by registering the application container in a central catalog.  
  - We can query to catalog to get the applications IP:Port information.
  - There is also a simple "health-check" ensuring the app is responsive as path "/"

- **Application:**
 - The **app.nomad** contains the configuration for the application and a side-car container running [NGINX](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/).
 - NGINX is configured as a [reverse-proxy](https://www.nginx.com/blog/nginx-ssl/) with SSL Offloading.
 - NGINX will terminate SSL and send traffic to the application container.


![sidecar](pics/side-car.png)


# Prerequisites:

We need a few things before we can begin
- Install [HomeBrew](https://brew.sh/)
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Install [Nomad](https://learn.hashicorp.com/tutorials/nomad/get-started-install)
- Install [openssl]()
- Install [mkcert](https://github.com/FiloSottile/mkcert)

If you are not familiar with HomeBrew, the commands to install the listed items are:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
brew cask install docker
```

```bash
brew install nomad
```

```bash
brew install openssl
```

```bash
brew install mkcert
```


### Create Self Signed Certificates

In order to utilize HTTPS for our local development, we need to create a Certificate Authority (CA) and sign our self-signed certificates.

Thankfully, there is a wonderful tool [mkcert](https://github.com/FiloSottile/mkcert) making this process as easy as possible.

#### Generate certificates

*All commands are run at root directory of the repository.*

1. **Get en0 IP address**

  ```bash
  LOCAL_IP=`ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}'`
  ```

  We will be running Nomad by binding the client to a non-loopback network interface as per this [Nomad FAQ](https://www.nomadproject.io/docs/faq#q-how-to-connect-to-my-host-network-when-using-docker-desktop-windows-and-macos)

  Because of this setup, we need the computers host address on inferface `en0` - hence the above command


2. **Create a CA**
  ```bash
  mkcert -install
  ```
  The command will create a new CA and install it directly to the root store of the OS (macOS in this case)

  The key and certificate are also stored on the system. you can see where by running
    ```bash
    mkcert -CAROOT
    ```


3. **Create signed certificates**
    ```bash
    mkcert localhost 127.0.0.1 ${LOCAL_IP}
    ```

    This command creates certificates valid for the given names | IP addresses.

      Example output:
    ```
      ✗ mkcert localhost 127.0.0.1 ${LOCAL_IP}

        Created a new certificate valid for the following names 📜
         - "localhost"
         - "127.0.0.1"
         - "192.168.2.136"

        The certificate is at "./localhost+2.pem" and the key at "./localhost+2-key.pem" ✅

        It will expire on 9 November 2023 🗓
      ```
      You should see similar **.pem** files in the repository now.

      ```
      .
├── README.md
├── app.nomad
├── consul.nomad
├── localhost+2-key.pem
├── localhost+2.pem
└── pics
    ├── allowNetwork.png
    └── side-car.png
    ```

4. **Copy the generated certificate file to macOS Keychain**

  Replace the **certificate** name with your generated filename

    ```bash
    sudo security add-trusted-cert -d -r trustAsRoot -k "/Library/Keychains/System.keychain" localhost+2.pem
    ```

    Alternatively you can drag and drop the file to your Keychain.
    You will then need to make sure to set **Always Trust** on the certificate settings.
    ![drag and drop](pics/draganddropcert.png)


#### Add certificates to the NGINX configuration

For local development purposes, the app.nomad file contains the NGINX configuration and the values for the **Certificate** and **Private Key**.We need to replace them with the ones generated on your workstation.

You can look at the file and probably derive what we need to update. Nevertheless, the instructions are below.


1. Copy the contents of **"certificate".pem** and paste it over the CERTIFICATE section in the app.nomad file.

 Include the
 ```
 -----BEGIN CERTIFICATE-----
 <contents>
 -----END CERTIFICATE-----
 ```

 Make sure the pasted certificate is indented all the way to the left. You can do this by highlighting the cert and presing `shift+tab`

2. Copy the contents of the **"certificate-key".pem** and paste over the PRIVATE key section in the app.nomad file

Include the

```
-----BEGIN PRIVATE KEY-----
<contents>
-----END PRIVATE KEY-----
```
Make sure the pasted certificate is indented all the way to the left. You can do this by highlighting the cert and presing `shift+tab`


# Start Nomad Cluster

Because MacOS and Windows runs Docker Desktop, there is a layer of indirection between the host network and the network of the VM running the containers.

Hashicorp recommends to start nomad and bind it to a network interface

1. Open a new Terminal tab and enter
```bash
   sudo nomad agent -dev -bind=0.0.0.0 -network-interface=en0 -log-level INFO
   ```

2. You may see a prompt to allow network connections. Select **Allow**
   Allow incoming network connections

   ![allow incoming network connections](pics/allowNetwork.png)

   The Nomad Cluster should be successfully running.

3. To view the Dashboard navigate to
  - [locahost:4646](http://localhost:4646/ui/jobs)

### Run Consul Job
Switch back to the **solution** repo in your terminal

*All commands are run at root of the repository.*

1. Run the `consul.nomad` file

```bash
nomad run consul.nomad
```

  It may take a minute, but he Task Group will return as healthy.

2. Take a look at the Nomad Dashboard where you can see the Consul job running
 - [localhost:4646](http://localhost:4646/ui/jobs)

3. you can also view the Consul Dashboard
  - [localhost:8500](http://localhost:8500/ui/dc1/services)

### Run Application Job

1. Run a plan of `app.nomad` file

   Lets make this slightly different by running a [plan](https://www.nomadproject.io/docs/commands/job/plan) to make sure our syntax is correct since we've edited the file.

  ```bash
  nomad job plan app.nomad
  ```

   If everything checks out we should see a similar output
```
  ✗ nomad job plan app.nomad

  + Job: "myJob"
  + Task Group: "web" (1 create)
    + Task: "app-server" (forces create)
    + Task: "nginx" (forces create)

  Scheduler dry-run:
  - All tasks successfully allocated.

  Job Modify Index: 0
  To submit the job with version verification run:

  nomad job run -check-index 0 app.nomad

  When running the job with the check-index flag, the job will only be run if the
  job modify index given matches the server-side version. If the index has
  changed, another user has modified the job and the plans results are
  potentially invalid.
```

  A plan does a dry-run of the schedule. The plan will not change anything in the cluster, but shows whether the job could be run successfully and how it would affect existing allocations

2. Run the `app.nomad` file

   Copy the `nomad job run -check-index ${index} app.nomad` command from the plan output and run it.

   ```bash
   nomad job run -check-index 0 app.nomad
   ```

   *alternatively you can just run*

   ```bash
   nomad job run app.nomad
   ```

   It may take a minute, but he Task Group will return as healthy.

3. Take a look at the Nomad Dashboard where you can see the job running

    - [locahost:4646](http://localhost:4646/ui/jobs)
      - You can click into the job to see details
      - Example:
        - Click on `example-app/web/<allocationid>/nginx/` to see details of the nginx task.
        - Explore the Logs and Files tabs

    ![nginx files](pics/nginxfiles.png)




4. Take a look at the Consul Services dahsboard

   - [localhost:8500](http://localhost:8500/ui/dc1/services)
    - We should now see the app-sever service registered.
      - Clicking into the app-server service will show us the node and service check status.


  ![app-service](pics/app-service.png)


# Check out the Application over HTTPS!

Our Application and the NGINX load balancer are running in the same [Group](https://www.nomadproject.io/docs/job-specification/group) which means the Tasks are running on the same Nomad client.

We need to point a browser to the `IP:Port` of the load balancer Since the Load Balancer is listening on port `443` we need to make sure the use `https://<ip_addr>:<port>`

### Find address via CLI

1. Let's get the Load Balancer address and port.

  ```bash
  nomad job status example-app
  ```

  The output will show us details about the job. We want to grab the `Allocation ID` at the bottom of the output

  Example Output:

  ```
    ➜  solution git:(master) ✗ nomad job status example-app
  ID            = example-app
  Name          = example-app
  Submit Date   = 2021-08-09T17:25:21-04:00
  Type          = service
  Priority      = 50
  Datacenters   = dc1
  Namespace     = default
  Status        = running
  Periodic      = false
  Parameterized = false

  Summary
  Task Group  Queued  Starting  Running  Failed  Complete  Lost
  web         0       0         1        0       0         0

  Latest Deployment
  ID          = 039a0215
  Status      = successful
  Description = Deployment completed successfully

  Deployed
  Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
  web         1        1       1        0          2021-08-09T17:35:46-04:00

  Allocations
  ID        Node ID   Task Group  Version  Desired  Status   Created    Modified
  2f0321f8  6006977c  web         0        run      running  8m10s ago  7m44s ago
  ```

2. Get the allocation status

  ```bash
  nomad alloc status 2f0321f8
  ```
 This will show us the allocation status details.

 Among the output is a section `Allocation Addresses`

 Example output snippit:

  ```
  Allocation Addresses
  Label  Dynamic  Address
  *http  yes      192.168.2.136:31280 -> 3000
  *lb    yes      192.168.2.136:21392 -> 443
  ```

3. Navigate to the address in your Browser (tested with Chrome and Safari)

  `https://192.168.2.136:21392`

  You should be presented with a secure connection

 ![secure connection](pics/scuresite.png)


### Find address via GUI

This involves lots of clicking. Let's dive in:

1. From the Homepage select `example-app`

2. Under Job / example-app look for the **Recent Allocations** section and cick on the `ID`

  ![allocation](pics/allocationsection.png)

3. You should see a Port section listing our defined `http` and `lb` ports.
 - Copy the lb `Host Address` and past into your browser address bar
  - Don't forget to use `https://`

  ![Ports](pics/ports.png)


# Cleanup

To cleanup:

Go to the Terminal where we started the Nomad Cluster and press `control + c` to exit out.

You can remove the Root CA cert and signed Certificate from the macOS Keychain if desired.
