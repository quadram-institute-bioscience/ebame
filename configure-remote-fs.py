import json
import os
import argparse
from subprocess import Popen

parser = argparse.ArgumentParser()
parser.add_argument("share_params", help="Parameters of the manila shared volumes (values in json format, { share_name: { access_level:...,protocol:...,endpoint:... } }")
parser.add_argument("-d", "--dst",
                    help="Local mounting points of the manila shared volume (default=/ifb/data)")
args = parser.parse_args()

def config_shares(data_manila_export, dst_dir="/ifb/data"):
    data = json.loads(data_manila_export)

    fn_fstab_ifb = open("ansible-remotefs.yaml", "w")
    fn_fstab_ifb.writelines("- hosts: all\n")
    fn_fstab_ifb.writelines("  tasks:\n")

    for k, v in data.items():
        if k == "ifb_proxy_enabled":
            with open('/etc/profile.d/ifb.sh', 'a') as ifb_profile:
                ifb_profile.write("export IFB_PROXY_ENABLED=True\n")
        else:
            dn_mountpoint = dst_dir + '/' + k
            os.makedirs(dn_mountpoint, exist_ok=True)

            params = v['protocol'] + "\t" + v['access_level'] + ",noauto,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.mount-timeout=30,_netdev"
            # if 'opts' in v.keys() and v['opts']:
            #     params += "," + v['opts']

            fn_fstab_ifb.writelines("  - name: Add mount point in fstab '" + k + "'\n")
            fn_fstab_ifb.writelines("    ansible.builtin.lineinfile:\n")
            fn_fstab_ifb.writelines("      path: /etc/fstab\n")
            fn_fstab_ifb.writelines("      regexp: '^" + v['endpoint'] + "'\n")
            fn_fstab_ifb.writelines("      line: '" + v['endpoint'] + "\t" + dn_mountpoint + "\t" + params + " 0 0'\n")
    fn_fstab_ifb.close()

if __name__ == '__main__':
    if args.dst:
        config_shares(args.share_params, dst_dir=args.dst)
    else:
        config_shares(args.share_params)