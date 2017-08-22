#
# identifyindexes.ps1
# run this against each database to find the actual indexes to run
# https://dba.stackexchange.com/questions/71365/when-to-rebuild-and-when-to-reorganize-indexes
<#
-- select database name
SELECT DB_NAME();

-- select only the indexes that need rebuilding

select
    ips.index_type_desc,
    ips.index_depth,
    ips.index_level,
    ips.avg_fragmentation_in_percent,
    ips.fragment_count,
    ips.page_count,
    ips.avg_page_space_used_in_percent,
    ips.record_count
FROM 
    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
INNER JOIN  
    sys.tables t ON ips.OBJECT_ID = t.Object_ID
INNER JOIN 
    sys.indexes i ON ips.index_id = i.index_id AND ips.OBJECT_ID = i.object_id
WHERE
    AVG_FRAGMENTATION_IN_PERCENT > 0.0 and page_count >1000 
ORDER BY
    AVG_FRAGMENTATION_IN_PERCENT, fragment_count

	#>