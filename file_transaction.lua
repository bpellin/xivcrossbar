local file_transaction = {}

local TEMP_SUFFIX = '.xivcrossbar.tmp'
local BACKUP_SUFFIX = '.xivcrossbar.bak'

local function is_empty_hotbar(content)
    return content ~= nil and content:match('<hotbar>%s*</hotbar>') ~= nil
end

local function cleanup_staged(entries, adapter)
    for _, entry in ipairs(entries) do
        adapter.remove(entry.path .. TEMP_SUFFIX)
    end
end

local function remove_existing(path, adapter)
    if not adapter.exists(path) then
        return true
    end
    return adapter.remove(path)
end

local function rollback(entries, committed_count, adapter)
    for index = committed_count, 1, -1 do
        local entry = entries[index]
        local path = entry.path
        local backup_path = path .. BACKUP_SUFFIX

        adapter.remove(path)
        if entry.had_original then
            adapter.rename(backup_path, path)
        end
    end
end

function file_transaction.write(entries, adapter)
    for _, entry in ipairs(entries) do
        local path = entry.path
        local temp_path = path .. TEMP_SUFFIX

        if type(entry.content) ~= 'string' then
            cleanup_staged(entries, adapter)
            return nil, 'Unable to serialize ' .. path .. '.'
        end

        entry.had_original = adapter.exists(path)
        if entry.had_original then
            local original, read_error = adapter.read(path)
            if original == nil then
                cleanup_staged(entries, adapter)
                return nil, 'Unable to read ' .. path .. ' before saving: ' .. tostring(read_error)
            end
            if not is_empty_hotbar(original) and is_empty_hotbar(entry.content) then
                cleanup_staged(entries, adapter)
                return nil, 'Refusing to replace non-empty ' .. path .. ' with an empty hotbar.'
            end
        end

        local removed, remove_error = remove_existing(temp_path, adapter)
        if not removed then
            cleanup_staged(entries, adapter)
            return nil, 'Unable to remove stale temporary file for ' .. path .. ': ' .. tostring(remove_error)
        end
        local wrote, write_error = adapter.write(temp_path, entry.content)
        if not wrote then
            cleanup_staged(entries, adapter)
            return nil, 'Unable to stage ' .. path .. ': ' .. tostring(write_error)
        end

        local staged, read_error = adapter.read(temp_path)
        if staged == nil or staged ~= entry.content then
            cleanup_staged(entries, adapter)
            return nil, 'Unable to verify staged data for ' .. path .. ': ' .. tostring(read_error or 'content mismatch')
        end
    end

    local committed_count = 0
    for index, entry in ipairs(entries) do
        local path = entry.path
        local temp_path = path .. TEMP_SUFFIX
        local backup_path = path .. BACKUP_SUFFIX

        local removed, remove_error = remove_existing(backup_path, adapter)
        if not removed then
            rollback(entries, committed_count, adapter)
            cleanup_staged(entries, adapter)
            return nil, 'Unable to replace backup for ' .. path .. ': ' .. tostring(remove_error)
        end
        if entry.had_original then
            local backed_up, backup_error = adapter.rename(path, backup_path)
            if not backed_up then
                rollback(entries, committed_count, adapter)
                cleanup_staged(entries, adapter)
                return nil, 'Unable to back up ' .. path .. ': ' .. tostring(backup_error)
            end
        end

        local installed, install_error = adapter.rename(temp_path, path)
        if not installed then
            if entry.had_original then
                adapter.rename(backup_path, path)
            end
            rollback(entries, committed_count, adapter)
            cleanup_staged(entries, adapter)
            return nil, 'Unable to install ' .. path .. ': ' .. tostring(install_error)
        end

        committed_count = index
    end

    return true
end


file_transaction.TEMP_SUFFIX = TEMP_SUFFIX
file_transaction.BACKUP_SUFFIX = BACKUP_SUFFIX

return file_transaction
