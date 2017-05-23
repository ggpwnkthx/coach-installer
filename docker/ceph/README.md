# Note

This makes deploying ceph very easy, but I would recommend setting up ceph without containers.

Multiple OSD on a single docker host IS supported with this method.

Multiple monitors and metadata servers in the ceph cluster IS supported. However, multiple MONs and MDSs on a single docker host is NOT recommended and actviely prevented using these scripts.
