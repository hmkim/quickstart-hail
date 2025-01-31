#!/bin/bash
set -x

cat > /var/tmp/fix-bootstap.sh <<'EOF'
#!/bin/bash
set -x

while true; do
    NODEPROVISIONSTATE=`sed -n '/localInstance [{]/,/[}]/{
    /nodeProvisionCheckinRecord [{]/,/[}]/ {
    /status: / { p }
    /[}]/a
    }
    /[}]/a
    }' /emr/instance-controller/lib/info/job-flow-state.txt | awk ' { print $2 }'`

    if [ "$NODEPROVISIONSTATE" == "SUCCESSFUL" ]; then
        echo "Running my post provision bootstrap"
        echo '-------BOOTSTRAP COMPLETE-------'

        exit
    else
        echo "Sleeping Till Node is Provisioned"
        sleep 10
    fi
done

EOF

chmod +x /var/tmp/fix-bootstap.sh
nohup /var/tmp/fix-bootstap.sh  2>&1 &

