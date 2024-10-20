![PS-github-logo](https://github.com/user-attachments/assets/2e5ea974-087d-4573-ab30-b4eae279cadb)
# Purple-Sight (Version V0.1)
**Precius is an OS security tool. (Our school annual Project for 2022-2023)**

**Purple-Sight is a web application to generate and control enumeration agents (Windows/Linux). For blue and/or red team. Each agent is fully modular and optimized to meet every need, from internal discrete services enumeration (Red team) to full OS vulnerability scanning (Blue Team).**



_Right now, if you successfully install Purple-Sight (which is already not easy, we need to work on that) you will have access to a local web application where you can create customizable compiled enumeration agent for Windows or Linux.
When deployed (manually copied/placed on a machine), each agent executes a predefined command and transmits their scans through an AES-256-CBC encrypted socket (or via API depending of the throwing module) to the web application.
On the web application you can manage your agents, see which one is active or not accessible, and activate them remotely (depending of their module). You can also check each scan to see their raw result/pretty result and click on a button to launch CVE-search on it to find the latest known vulnerability._

# Interface web screenshot
(Sorry, it is in french)
### Main page
![image](https://github.com/user-attachments/assets/71c86dec-98f4-48cc-9469-f57215417b28)

### Agent creation
![image](https://github.com/user-attachments/assets/a5772816-e4f3-40ba-87e7-26146004525f)

### Agent management
![image](https://github.com/user-attachments/assets/cf1af8ea-2e35-4217-8ada-e99b3ddddfee)

### Scans management
![image](https://github.com/user-attachments/assets/823d38fb-7224-4ee5-820e-d5b4ff99085c)

### Scans check up
![image](https://github.com/user-attachments/assets/7946549c-b542-4d9f-b70c-0b10f921ff6d)


# installation
(not finished, need more explanation and a clear methodologie)

Purple-Sight need a linux server, Download and place on your linux server the ApplicationWeb.zip file

# Improvement
There are _**tons**_ of improvement we must do to achieve the full potential of Purple-Sight. Here are some of them :

### More agent module
Agents are made of 3 modules each on a thread, the executing module, the sending module, and the receiving module.
Purple-Sight agent strength is their design, which was coded to easily switch module to be perfect for every need.
so.. we need a lot more modules for each category :
 - for executing module : (multi-threading, process injeciton, scripts)
 - for sending module : (fpt & sftp, HTTPS (only http for now when the API module is selected))
 - for listening module : (persistant, bind)
 
### Encrypt client data on server
For now, Purple does not encrypt scans when they are stored... which is pretty bad for a security solution.

### Web application improvment
Right now it is ok... but we could do a lot better. We could also go to new web technologies instead of the old full PHP

### Add more scan filters
One of the first Purple-Sight concept was to have scan filter, for each agents scan we would have a list of filter to be applied on it. Each filter will process differently the scan to highlight different information.
For now, we only have the CVE-Search filter which shows every known vulnerability for our scan.

### Add diff to scans
Since a scan is just a 'screenshot' of an OS with a list of command, we can add the option to compare 2 scans to show each differences like new application/service/driver installed between one scan and another.



...(add we have a lot more)...
