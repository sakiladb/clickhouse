#!/usr/bin/env python3
"""
Convert MySQL Sakila data to ClickHouse format.
- Prefixes table names with sakila.
- Converts special_features SET to Array syntax.
- Removes BLOB data from staff.picture column.
- Removes MySQL-specific syntax (LOCK TABLES, SET AUTOCOMMIT, etc.)
"""

import re
import sys

def convert_special_features(match):
    """Convert SET values like 'Trailers,Commentaries' to ['Trailers', 'Commentaries']"""
    content = match.group(1)
    if content == '' or content is None:
        return '[]'
    features = content.split(',')
    return "[" + ",".join(f"'{f.strip()}'" for f in features) + "]"

def process_film_line(line):
    """Process film INSERT to convert special_features SET to Array"""
    # Pattern to match the special_features column (second to last before the timestamp)
    # Format: ...,'rating','special_features','timestamp')
    # We need to find patterns like 'Trailers,Deleted Scenes' and convert to ['Trailers','Deleted Scenes']

    # The special_features is between rating and last_update
    # Pattern: 'G','Deleted Scenes,Behind the Scenes','2006-02-15 05:03:42')
    # Should become: 'G',['Deleted Scenes','Behind the Scenes'],'2006-02-15 05:03:42')

    # Also handle NULL case for special_features
    line = re.sub(r",NULL,'(\d{4}-\d{2}-\d{2})", r",[],'\\1", line)

    # Match the pattern: 'RATING','features','timestamp')
    # where features can contain commas
    def replace_features(m):
        rating = m.group(1)
        features_str = m.group(2)
        timestamp = m.group(3)

        if features_str == '' or features_str == 'NULL':
            return f"'{rating}',[],'{timestamp}')"

        features = features_str.split(',')
        array_str = "[" + ",".join(f"'{f.strip()}'" for f in features) + "]"
        return f"'{rating}',{array_str},'{timestamp}')"

    # Pattern for: 'RATING','features_with_possible_commas','timestamp')
    line = re.sub(r"'(G|PG|PG-13|R|NC-17)','([^']*?)','(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'\)", replace_features, line)

    return line

def process_staff_line(line):
    """Process staff INSERT to remove BLOB picture data"""
    # Staff format: (id,'first','last',address_id,BLOB_DATA,'email',store_id,active,'username','password','timestamp')
    # Need to remove the BLOB_DATA (which is 0x... hex OR NULL)
    # Result should be: (id,'first','last',address_id,'email',store_id,active,'username','password','timestamp')

    # Match the BLOB hex data pattern
    line = re.sub(r',0x[0-9A-Fa-f]+,', ',', line)

    # Also handle NULL picture - pattern: ,address_id,NULL,'email' -> ,address_id,'email'
    # Need to be careful to only match the picture column position
    # Pattern: number,NULL,' (after address_id which is a number)
    line = re.sub(r'(\d),NULL,\'', r"\1,'", line)

    return line

def process_address_line(line):
    """Process address INSERT to remove GEOMETRY data"""
    # Address has a GEOMETRY column with MySQL-specific syntax: /*!50705 0x...,*/
    # Remove these conditional comments with GEOMETRY data
    line = re.sub(r'/\*!\d+ 0x[0-9A-Fa-f]+,\*/', '', line)

    return line

def main():
    input_file = sys.argv[1] if len(sys.argv) > 1 else '../mysql/2-sakila-data.sql'
    output_file = sys.argv[2] if len(sys.argv) > 2 else '2-clickhouse-sakila-data.sql'

    current_table = None

    with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
        # Write header
        f_out.write("-- Sakila Sample Database Data for ClickHouse\n")
        f_out.write("-- Converted from MySQL Sakila database\n")
        f_out.write("-- Version 1.2\n\n")
        f_out.write("-- Copyright (c) 2006, 2019, Oracle and/or its affiliates.\n")
        f_out.write("-- All rights reserved.\n")
        f_out.write("-- BSD License\n\n")

        for line in f_in:
            # Skip MySQL-specific commands
            if line.startswith('SET ') or line.startswith('USE ') or line.startswith('LOCK ') or line.startswith('UNLOCK ') or line.startswith('COMMIT'):
                continue

            # Track current table for INSERT statements
            if 'Dumping data for table' in line:
                match = re.search(r'table\s+`?(\w+)`?', line)
                if match:
                    current_table = match.group(1)
                # Write comment
                f_out.write(line)
                continue

            # Skip film_text table data (populated by triggers in MySQL)
            if current_table == 'film_text':
                if line.startswith('INSERT'):
                    continue

            # Process INSERT statements
            if line.startswith('INSERT INTO'):
                # Get table name and prefix with sakila.
                line = re.sub(r'INSERT INTO `?(\w+)`?', r'INSERT INTO sakila.\1', line)

                # Process based on table
                if current_table == 'film':
                    line = process_film_line(line)
                elif current_table == 'staff':
                    line = process_staff_line(line)
                elif current_table == 'address':
                    line = process_address_line(line)

                f_out.write(line)
            elif line.startswith('(') and current_table:
                # Continuation of INSERT VALUES
                if current_table == 'film':
                    line = process_film_line(line)
                elif current_table == 'staff':
                    line = process_staff_line(line)
                elif current_table == 'address':
                    line = process_address_line(line)
                elif current_table == 'film_text':
                    continue

                f_out.write(line)
            elif line.strip().startswith('--'):
                # Keep comments
                f_out.write(line)
            elif line.strip() == '':
                f_out.write(line)

if __name__ == '__main__':
    main()
