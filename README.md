# Livy parcel for Cloudera CDH5 #

Enables the creation of a parcel and CSD to install Livy on a Cloudera CDH5 cluster.

### Building ###

Use the following commands to build the CSD and parcel:

```bash
./build.sh all
```


### Parcel installation ###

0. The CSD, parcel and checksum files are generated in the `target` directory.
1. Copy the generated CSD file to `/opt/cloudera/csd` on the CM Manager node.
2. Copy the `LIVY-0.6.0-el7.parcel` parcel file to `/opt/cloudera/parcel-repo` on the CM Manager node.
3. Also copy the `LIVY-0.6.0-el7.parcel.sha` file (containing the SHA1 checksum of the parcel file).
4. Restart the `cloudera-scm-server` service (or, in recent CM versions, you can just check for new parcels).
5. Distribute and activate the parcel via Cloudera Manager.


If you have a webserver available, you can also replace steps 2 and 3 above with:

2. Make the generated `LIVY-0.6.0-el7.parcel` and `manifest.json` files available via the webserver.
3. Add this location as a parcel source in Cloudera Manager.


### Service installation and configuration ###

1. In Cloudera Manager, choose `Add Service` to add a Livy REST service to one or more (edge) nodes.
2. Enable impersonation for the `livy` user:

    1. In the HDFS service configuration, under `Cluster-wide Advanced Configuration Snippet (Safety Valve) for core-site.xml`, 
        add two name/value/description triplets:
	 
	     | | |
	     | --- | -------- |
	     | Name | hadoop.proxyuser.livy.hosts |
	     | Value | <comma-separated list of the FQDNs on which Livy is installed> |
	     | Description | Comma-delimited list of hosts that you want to allow the LIVY user to impersonate. The default '*' allows all hosts. To disable entirely, use a string that does not correspond to a host name, such as '_no_host'.

	     | | |
	     | --- | -------- |
	     | Name | hadoop.proxyuser.livy.groups |
	     | Value | * |
	     | Description | Comma-delimited list of groups that you want to allow the LIVY user to impersonate. The default '*' allows all groups. To disable entirely, use a string that does not correspond to a group name, such as '_no_group_'. |


    2. Restart HDFS and all dependent services (i.e. basically everything) to activate the changes.


3. Configure the Livy service:

    | Name | Value |
    | --- | ------- |
    | Livy Spark Version | spark2 |
    | Enable user authentication | true |
    | Enable TLS/SSL for Livy REST server | true |
   
    Also fill in the details for the SSL certificate.
   
4. In Cloudera Manager, under `Administration` - `Security` - `Kerberos Credentials`, check that principals for the Livy REST server(s) have been created.
    If not, use `Generate missing credentials` to do so.
   
5. Start Livy.
   
  
### Links ###

* This is based on [https://github.com/alexjbush/livy_zeppelin_cdh_csd_parcels]
* More info on parcels can be found at: [https://github.com/cloudera/cm_ext/wiki]
