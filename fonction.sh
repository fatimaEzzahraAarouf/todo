#!/bin/bash

create_task() {
    if [ -f "liste.json" ]; then
        id=$(jq '.tasks[-1].id' liste.json)
        ((id++))
    else
        id=0
    fi

    echo "Task ID: $id" >&2

    while true; do 
        read -p "Give a title to your new task: " title
        if [[ -z "$title" ]]; then 
            echo "Title is required" >&2
        else 
            break
        fi 
    done

    read -p "Description: " description
    read -p "Location: " location

    while true; do 
        read -p "Date (YYYY-MM-DD): " date
        read -p "Time (HH:MM): " time
        if [[ -z "$date" || -z "$time" ]]; then 
            echo "Time and date are required" >&2
        elif ! [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "Invalid date format. Use YYYY-MM-DD." >&2
        elif ! [[ "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            echo "Invalid time format. Use HH:MM." >&2
        else 
            break
        fi 
    done

    task_state="not completed"

    new_task=$(jq -n \
                  --arg id "$id" \
                  --arg title "$title" \
                  --arg description "$description" \
                  --arg location "$location" \
                  --arg time "$time" \
                  --arg date "$date" \
                  --arg task_state "$task_state" \
                  '{id: $id|tonumber, title: $title, description: $description, location: $location, time: $time, date: $date, task_state: $task_state}')

    if [ -f "liste.json" ]; then
        jq --argjson new_task "$new_task" '.tasks += [$new_task]' liste.json > temp.json
        mv temp.json liste.json
    else
        echo "{\"tasks\": [$new_task]}" > liste.json
    fi
}

update_task() {
    read -p "Enter task ID to update: " id
    if ! jq -e ".tasks[] | select(.id==$id)" liste.json > /dev/null; then
        echo "Task ID $id not found." >&2
        return
    fi

    read -p "New title (leave empty to keep current): " title
    read -p "New description (leave empty to keep current): " description
    read -p "New location (leave empty to keep current): " location
    read -p "New date (YYYY-MM-DD, leave empty to keep current): " date
    read -p "New time (HH:MM, leave empty to keep current): " time
    read -p "New state (completed/not completed, leave empty to keep current): " state

    jq --argjson id "$id" \
       --arg title "$title" \
       --arg description "$description" \
       --arg location "$location" \
       --arg date "$date" \
       --arg time "$time" \
       --arg state "$state" \
       '
       (.tasks[] | select(.id == $id) | .title) = (if $title == "" then .title else $title end) |
       (.tasks[] | select(.id == $id) | .description) = (if $description == "" then .description else $description end) |
       (.tasks[] | select(.id == $id) | .location) = (if $location == "" then .location else $location end) |
       (.tasks[] | select(.id == $id) | .date) = (if $date == "" then .date else $date end) |
       (.tasks[] | select(.id == $id) | .time) = (if $time == "" then .time else $time end) |
       (.tasks[] | select(.id == $id) | .task_state) = (if $state == "" then .task_state else $state end)
       ' liste.json > temp.json
    mv temp.json liste.json
}

delete_task() {
    read -p "Enter task ID to delete: " id
    if ! jq -e ".tasks[] | select(.id==$id)" liste.json > /dev/null; then
        echo "Task ID $id not found." >&2
        return
    fi

    jq --argjson id "$id" 'del(.tasks[] | select(.id == $id))' liste.json > temp.json
    mv temp.json liste.json
    echo "Task ID $id deleted."
}

show_task() {
    read -p "Enter task ID to show: " id
    task=$(jq -r --argjson id "$id" '.tasks[] | select(.id == $id)' liste.json)
    if [ -z "$task" ]; then
        echo "Task ID $id not found." >&2
    else
        echo "$task" | jq .
    fi
}

list_tasks() {
    read -p "Enter date (YYYY-MM-DD) to list tasks: " date
    tasks=$(jq -r --arg date "$date" '.tasks[] | select(.date == $date)' liste.json)
    if [ -z "$tasks" ]; then
        echo "No tasks found for $date."
    else
        echo "Tasks for $date:"
        echo "$tasks" | jq -r '. | "\(.id): \(.title) (\(.task_state))"'
    fi
}

search_tasks() {
    read -p "Enter title to search for: " title
    tasks=$(jq -r --arg title "$title" '.tasks[] | select(.title | contains($title))' liste.json)
    if [ -z "$tasks" ]; then
        echo "No tasks found with title containing '$title'."
    else
        echo "Tasks with title containing '$title':"
        echo "$tasks" | jq -r '. | "\(.id): \(.title) (\(.task_state))"'
    fi
}

list_todays_tasks() {
    date=$(date +%F)
    tasks=$(jq -r --arg date "$date" '.tasks[] | select(.date == $date)' liste.json)
    if [ -z "$tasks" ]; then
        echo "No tasks for today ($date)."
    else
        echo "Today's tasks ($date):"
        echo "$tasks" | jq -r '. | "\(.id): \(.title) (\(.task_state))"'
    fi
}

if [ $# -eq 0 ]; then
    list_todays_tasks
else
    case "$1" in
        create)
            create_task
            ;;
        update)
            update_task
            ;;
        delete)
            delete_task
            ;;
        show)
            show_task
            ;;
        list)
            list_tasks
            ;;
        search)
            search_tasks
            ;;
        *)
            echo "Usage: $0 {create|update|delete|show|list|search}"
            exit 1
            ;;
    esac
fi
