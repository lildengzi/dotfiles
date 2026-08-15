function cb
    taskset -c 0-14 cargo $argv
end
