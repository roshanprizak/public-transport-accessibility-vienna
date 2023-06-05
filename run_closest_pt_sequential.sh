for d in {1..23}; do
    echo $d
    for t in {0..3}; do
        FILENAME="closest_pt/closest_pt_${t}_${d}.csv"
        FILEEXISTS=0
        if test -f "$FILENAME"; then
            FILEEXISTS=1
            echo "$FILENAME exists already."
        fi
        while [ $FILEEXISTS -ne 1 ]
        do
            python compute_nearest_pt.py -d $d -t $t;
            break
        done
    done
done
