#!/bin/bash
#  ____ ____ ____ ____ ____ 
# ||S |||K |||D |||B |||G ||
# ||__|||__|||__|||__|||__||
# |/__\|/__\|/__\|/__\|/__\|
#
# SKDBG : Static KeePass Database Generator
# Dependencies : keepassxc-cli, xmlstarlet
#
# Fork one admin DB into multiple user DBs
# Push modifications from users to admin DB
# Usage : Launch each time a DB is modified

db="admin"
dbPass="admin"

xRootPath="KeePassFile/Root/Group"

exportAdminDatabase() {

  # This function exports admin KeePass database (KDBX)
  # into clear XML.

  if echo "$dbPass" |
    keepassxc-cli export \
    --quiet \
    --format xml \
    "${db}".kdbx > ${db}.xml 2> /dev/null

  then
    echo "Successfully exported ${db}.kdbx"

  else
    echo "Database ${db}.kdbx can't be opened."
    exit 1
  fi
  
  # Remove 'History' nodes
  xmlstarlet edit \
    --inplace \
    --delete "//History" ${db}.xml

}

importAdminDatabase() {

  # This function imports admin KeePass database (XML)
  # into password encrypted KeePass file (KDBX).
  # This will be called only on first use in order to remove
  # "correct" timestamps.

  # Backup Admin DB
  mv "${db}.kdbx" "${db}.kdbx.bak"

  if echo -e "${dbPass}\n${dbPass}" |
    keepassxc-cli import \
    --quiet \
    "${db}.xml" \
    "${db}.kdbx" \
    2> /dev/null

  then
    echo "Successfully imported ${db}.xml"
    rm --force "${db}.kdbx.bak"

  else
    echo "Error while importing ${db}.xml"
    mv "${db}.kdbx.bak" "${db}.kdbx" &&
      echo "Backup restored"
    exit 1
  fi

  rm --force "${db}.xml"

}

exportUserDatabases() {

  # This function tries to export each KeePass database 
  # as mentioned in 'Users' group from main DB.

  # Get user databases name
  databases=($(xmlstarlet select \
    --template \
    --match "${xRootPath}/Group[Name='Users']/Entry" \
    --match "String[Key='Title']" \
    --value-of "Value" \
    --nl \
    ${db}.xml)
  )
  
  # Get user databases password
  databasesPasswords=($(xmlstarlet select \
    --template \
    --match "${xRootPath}/Group[Name='Users']/Entry" \
    --match "String[Key='Password']" \
    --value-of "Value" \
    --nl \
    ${db}.xml)
  )

  for user in ${!databases[@]}; do
  
    databaseName="${databases[$user]}"
    databasePass="${databasesPasswords[$user]}"
  
    # Check if database actually exists
    if [ -f ${databaseName}.kdbx ]; then
  
      # Try exporting it to XML
      if echo "$databasePass" |
        keepassxc-cli export \
        --quiet \
        --format xml \
        "${databaseName}.kdbx" \
        > "${databaseName}.xml" \
        2> /dev/null
  
      then
        echo "Successfully exported ${databaseName}.kdbx"
  
      else
        echo "Database ${databaseName}.kdbx can't be opened."
        unset 'databases[user]'
        unset 'databasesPasswords[user]'
        continue
      fi
  
    else 
  
      echo "Database ${databaseName} does not exists, skip."
      unset 'databases[user]'
      unset 'databasesPasswords[user]'
      continue
  
    fi
  
    # Remove 'History' nodes
    xmlstarlet edit \
      --inplace \
      --delete "//History" \
      "${databaseName}.xml"
  
  done

}

getParentGroup() {

  userDatabaseGroup="${1}"
  userDatabaseName="${2}"

  # Get parent group UUID from User
  userDatabaseGroupParent=$(
    xmlstarlet select \
      --template \
      --match \
      "//Group[UUID='${userDatabaseGroup}']/.." \
      --value-of "UUID" \
      "${userDatabaseName}.xml"
  )

  # Get parent group UUID from Admin
  adminDatabaseGroupParent=$(
    xmlstarlet select \
      --template \
      --match \
      "//Group[UUID='${userDatabaseGroupParent}']" \
      --value-of "UUID" \
      "${db}.xml"
  )

  # If parent group exists, append group here
  if [ ! -z "${adminDatabaseGroupParent}" ]; then

    # Get group name from User
    userDatabaseGroupName=$(
      xmlstarlet select \
        --template \
        --match \
        "//Group[UUID='${userDatabaseGroup}']" \
        --value-of "Name" \
        "${userDatabaseName}.xml"
    )

    groupPlaceholder="Group-Placeholder"

    # Append "Group" node to Admin DB
    xmlstarlet edit \
      --inplace \
      --subnode \
      "//Group[UUID='${userDatabaseGroupParent}']" \
      --type elem \
      -n "${groupPlaceholder}" \
      --subnode \
      "//Group[UUID='${userDatabaseGroupParent}']/${groupPlaceholder}" \
      --type elem \
      -n "UUID" \
      --value "${userDatabaseGroup}" \
      --subnode \
      "//Group[UUID='${userDatabaseGroupParent}']/${groupPlaceholder}" \
      --type elem \
      -n "Name" \
      --value "${userDatabaseGroupName}" \
      --rename \
      "//Group[UUID='${userDatabaseGroupParent}']/${groupPlaceholder}" \
      --value "Group" \
      "${db}.xml"

  # If not, search for another parent
  else
    getParentGroup \
      "${userDatabaseGroupParent}" \
      "${userDatabaseName}"
  fi

}

insertUserEntry() {

  userDatabaseEntry="${1}"
  userDatabaseName="${2}"

  # Get group UUID of User entry
  userDatabaseEntryGroup=$(
    xmlstarlet select \
      --template \
      --match \
      "//Entry[UUID='${userDatabaseEntry}']/.." \
      --value-of "UUID" \
      --nl \
      "${userDatabaseName}.xml"
  )

  # Get group name from Admin DB
  adminDatabaseEntryGroupName=$(
    xmlstarlet select \
      --template \
      --match \
      "//Group[UUID='${userDatabaseEntryGroup}']" \
      --value-of "Name" \
      "${db}.xml"
  )

  # Check if group exists in Admin DB
  if [ ! -z "${adminDatabaseEntryGroupName}" ]
  then

    entryPlaceholder="Entry-Placeholder"

    # Append "Entry" node to Admin DB
    xmlstarlet edit \
      --inplace \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']" \
      --type elem \
      -n "${entryPlaceholder}" \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}" \
      --type elem \
      -n "UUID" \
      --value "${userDatabaseEntry}" \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}" \
      --type elem \
      -n "Tags" \
      --value "${userDatabaseName}" \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}" \
      --type elem \
      -n "IconID" \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}" \
      --type elem \
      -n "Times" \
      --subnode \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}/Times" \
      --type elem \
      -n "LastModificationTime" \
      --rename \
      "//Group[UUID='${userDatabaseEntryGroup}']/${entryPlaceholder}" \
      --value "Entry" \
      "${db}.xml"

  else

    # Search for a parent group
    getParentGroup "${userDatabaseEntryGroup}" "${userDatabaseName}"
    insertUserEntry "${userDatabaseEntry}" "${userDatabaseName}"

  fi

}

pushUserModifications() {

  # This function merges modifications from users with
  # main XML DB, based on cached times in '.cache' file.

  for user in ${!databases[@]}; do
  
    userDatabaseName="${databases[$user]}"
    userDatabaseEntries=($(xmlstarlet select \
      --template \
      --match \
      "//Entry" \
      --value-of "UUID" \
      --nl \
      "${userDatabaseName}.xml")
    )
  
    # Loop through each User Entry
    for userDatabaseEntry in "${userDatabaseEntries[@]}"; do

      # Get User Entry Time
      userDatabaseEntryTimeCRC=$(xmlstarlet select \
        --template \
        --match "//Entry[UUID='${userDatabaseEntry}']" \
        --match "Times" \
        --value-of "LastModificationTime" \
        --nl \
        "${userDatabaseName}.xml"
      )

      # Get Admin Entry Time
      adminDatabaseEntryTimeCRC=$(
        grep "${userDatabaseEntry}" .cache |
          cut -d ";" -f2
      )

      # If Time CRCs does not match, push modification
      if [ "${userDatabaseEntryTimeCRC}" != "${adminDatabaseEntryTimeCRC}" ]
      then

        # Check if entry is new
        if [ -z "${adminDatabaseEntryTimeCRC}" ]; then

          echo "$userDatabaseName created $userDatabaseEntry"
          insertUserEntry "${userDatabaseEntry}" "${userDatabaseName}"

        else
          echo "$userDatabaseName modified $userDatabaseEntry"
        fi
  
        # Get IconID attribute from user
        userDatabaseEntryIconID=$(xmlstarlet select \
          --template \
          --match \
          "//Entry[UUID='${userDatabaseEntry}']" \
          --value-of \
          "IconID" \
          "${userDatabaseName}.xml"
        )

        # Overwrite LastModificationTime
        xmlstarlet edit \
          --inplace \
          --update \
          "//Entry[UUID='${userDatabaseEntry}']/Times/LastModificationTime" \
          --value \
          "$userDatabaseEntryTimeCRC" \
          "${db}.xml"
  
        # Overwrite IconID
        xmlstarlet edit \
          --inplace \
          --update \
          "//Entry[UUID='${userDatabaseEntry}']/IconID" \
          --value \
          "$userDatabaseEntryIconID" \
          "${db}.xml"
  
        # Remove Admin Strings
        xmlstarlet edit \
          --inplace \
          --delete \
          "//Entry[UUID='${userDatabaseEntry}']/String" \
          "${db}.xml"
  
        # Get String Keys from User
        mapfile -t userDatabaseStringKeys < <( xmlstarlet select \
          --template \
          --match \
          "//Entry[UUID='${userDatabaseEntry}']/String" \
          --value-of "Key" \
          --nl \
          "${userDatabaseName}.xml"
        )
  
        # Get String Values from User
        mapfile -t userDatabaseStringValues < <( xmlstarlet select \
          --template \
          --match \
          "//Entry[UUID='${userDatabaseEntry}']/String" \
          --value-of "Value" \
          --nl \
          "${userDatabaseName}.xml"
        )
  
        # Append each User String to Admin XML
        for stringIndex in "${!userDatabaseStringKeys[@]}"; do
  
          stringKey="${userDatabaseStringKeys[${stringIndex}]}"
          stringValue="${userDatabaseStringValues[${stringIndex}]}"

          stringPlaceholder="String-Placeholder"
  
          xmlstarlet edit \
            --inplace \
            --subnode \
            "//Entry[UUID='${userDatabaseEntry}']" \
            --type "elem" -n "${stringPlaceholder}" \
            --subnode \
            "//Entry[UUID='${userDatabaseEntry}']/${stringPlaceholder}" \
            --type "elem" -n "Key" --value "${stringKey}" \
            --subnode \
            "//Entry[UUID='${userDatabaseEntry}']/${stringPlaceholder}" \
            --type "elem" -n "Value" --value "${stringValue}" \
            --rename \
            "//Entry[UUID='${userDatabaseEntry}']/${stringPlaceholder}" \
            --value "String" "${db}.xml"
  
        done

      fi
  
    done
  
  done

}

forkAdminDatabase() {

  # This function makes copies of main XML and remove 
  # nodes according to its tags.

  # Get entries from Admin DB
  adminDatabaseEntries=($(xmlstarlet select \
    --template \
    --match \
    "//Entry" \
    --value-of "UUID" \
    --nl \
    "${db}.xml")
  )
  
  # Get groups from Admin DB
  adminDatabaseGroups=($(xmlstarlet select \
    --template \
    --match "//Group" \
    --value-of "UUID" \
    --nl \
    "${db}.xml")
  )
  adminDatabaseGroupsLength="${#adminDatabaseGroups[@]}"
  ((adminDatabaseGroupsLength--))
  
  # Get users from Admin DB
  databases=($(xmlstarlet select \
    --template \
    --match "${xRootPath}/Group[Name='Users']/Entry" \
    --match "String[Key='Title']" \
    --value-of "Value" \
    --nl \
    ${db}.xml)
  )
  
  # Cache timestamps CRCs of Admin entries
  touch .cache
  for entry in "${adminDatabaseEntries[@]}"; do
  
    # Get Time CRC
    timeCRC=$(
      xmlstarlet select \
        --template \
        --match "//Entry[UUID='${entry}']/Times" \
        --value-of "LastModificationTime" \
        --nl \
        "${db}.xml"
    )

    # Update cache
    grep --invert-match "${entry}" .cache > .cache.tmp
    mv .cache.tmp .cache
    echo "${entry};${timeCRC}" >> .cache
  
  done

  for database in "${databases[@]}"; do
  
    cp "${db}.xml" "${database}.xml"
  
    # For each entry, check if its tags match user database
    for entry in "${adminDatabaseEntries[@]}"; do
  
      tags=($(xmlstarlet select \
        --template \
        --match \
        "//Entry[UUID='${entry}']" \
        --value-of "Tags" \
        --nl \
        "${database}.xml" |
        cut -d "," -f1- \
        --output-delimiter=$'\n')
      )
  
      delete="yes"
      for tag in "${tags[@]}"; do
        if [ "${tag}" == "${database}" ]; then
          delete="no"
        fi
      done
  
      # No tag, remove entry
      if [ "${delete}" == "yes" ]; then
        xmlstarlet edit \
          --inplace \
          --delete \
          "//Entry[UUID='${entry}']" \
          "${database}.xml"
  
      # Tag is present, remove its mention
      else
        xmlstarlet edit \
          --inplace \
          --update \
          "//Entry[UUID='${entry}']/Tags" \
          --value "" \
          "${database}.xml"
      fi
  
    done
  
    # Remove empty groups from new user DB
    for (( i=$adminDatabaseGroupsLength; i>=0; i-- )); do
  
      group="${adminDatabaseGroups[${i}]}"
  
      # Check if it contains a group
      if xmlstarlet select \
        --template \
        --match \
        "//Group[UUID='${group}']" \
        --match "Group" \
        --value-of "UUID" \
        --nl \
        "${database}.xml" \
        > /dev/null; then
  
        # Keep that group, do nothing
        :
  
      else
  
        # If not, check if it contains an entry
        if xmlstarlet select \
          --template \
          --match \
          "//Group[UUID='${group}']" \
          --match "Entry" \
          --value-of "UUID" \
          --nl \
          "${database}.xml" \
          > /dev/null; then
  
          # Keep that group, do nothing
          :
  
        # If not, remove it (empty group)
        else
          xmlstarlet edit \
            --inplace \
            --delete \
            "//Group[UUID='${group}']" \
            "${database}.xml"
        fi
  
      fi
  
    done
  
  done

}

importAllXML() {

  # This function transforms all clear XML databases
  # into password crypted KeePass databases (KDBX).

  # Get passwords from Admin DB
  databasesPasswords=($(xmlstarlet select \
    --template \
    --match "${xRootPath}/Group[Name='Users']/Entry" \
    --match "String[Key='Password']" \
    --value-of "Value" \
    --nl \
    ${db}.xml)
  )
  
  # Import Users
  for user in "${!databases[@]}"; do
  
    databaseName="${databases[${user}]}"
    databasePass="${databasesPasswords[${user}]}"

    # Backup KDBX
    mv "${databaseName}.kdbx" \
      "${databaseName}.kdbx.bak" \
      2> /dev/null

    if echo -e "${databasePass}\n${databasePass}" |
      keepassxc-cli import \
        --quiet \
        "${databaseName}.xml" \
        "${databaseName}.kdbx" \
        2> /dev/null

    then
      echo "Successfully imported ${databaseName}.xml"
      rm --force "${databaseName}.kdbx.bak"

    else
      echo "Error while importing ${databaseName}.xml"
      mv "${databaseName}.kdbx.bak" "${databaseName}.kdbx" &&
        echo "Backup restored."
    fi
  
    rm --force "${databaseName}.xml"
  
  done
  
  # Import Admin
  mv "${db}.kdbx" "${db}.kdbx.bak"
  
  if echo -e "${dbPass}\n${dbPass}" |
    keepassxc-cli import \
      --quiet \
      "${db}.xml" \
      "${db}.kdbx" \
      2> /dev/null

  then
    echo "Successfully imported ${db}.xml"
    rm --force "${db}.kdbx.bak"

  else
    echo "Error while importing ${db}.xml"
    mv "${db}.kdbx.bak" "${db}.kdbx" &&
      echo "Backup restored."
  fi
  
  rm --force "${db}.xml"
  
}

# Check if Admin database exists
if [ -f "${db}.kdbx" ]; then

  exportAdminDatabase

  # Check if cache exists
  if [ -f ".cache" ]; then

    exportUserDatabases
    pushUserModifications

  else

    # First use : remove timestamps
    importAdminDatabase
    exportAdminDatabase

    # Continue
    exportUserDatabases
    pushUserModifications

  fi

  forkAdminDatabase
  importAllXML

else

  echo "Admin database does not exists."
  exit 1

fi
