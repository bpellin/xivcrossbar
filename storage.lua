--[[
        Copyright © 2017, SirEdeonX
        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:

            * Redistributions of source code must retain the above copyright
              notice, this list of conditions and the following disclaimer.
            * Redistributions in binary form must reproduce the above copyright
              notice, this list of conditions and the following disclaimer in the
              documentation and/or other materials provided with the distribution.
            * Neither the name of xivhotbar nor the
              names of its contributors may be used to endorse or promote products
              derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
        ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
        DISCLAIMED. IN NO EVENT SHALL SirEdeonX BE LIABLE FOR ANY
        DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
        (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
        LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
        ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
        (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
        SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

local storage = {}
local file_transaction = require('file_transaction')
local split_hotbar

storage.filename = ''
storage.directory = ''
storage.file = nil

local filesystem = {}

function filesystem.exists(path)
    return windower.file_exists(path)
end

function filesystem.read(path)
    local handle, open_error = io.open(path, 'rb')
    if handle == nil then
        return nil, open_error
    end

    local content, read_error = handle:read('*all')
    handle:close()
    return content, read_error
end

function filesystem.write(path, content)
    local handle, open_error = io.open(path, 'wb')
    if handle == nil then
        return nil, open_error
    end

    local wrote, write_error = handle:write(content)
    if wrote == nil then
        handle:close()
        return nil, write_error
    end

    local flushed, flush_error = handle:flush()
    local closed, close_error = handle:close()
    if flushed == nil then
        return nil, flush_error
    end
    if closed == nil then
        return nil, close_error
    end

    return true
end


function filesystem.remove(path)
    if not filesystem.exists(path) then
        return true
    end
    return os.remove(path)
end


function filesystem.rename(source, destination)
    return os.rename(source, destination)
end


local function serialize_hotbars(new_hotbar)
    local job_sub_hotbar, job_hotbar, all_jobs_hotbar = split_hotbar(new_hotbar)
    local serialized = {}
    local hotbars = {job_sub_hotbar, job_hotbar, all_jobs_hotbar}

    for index, hotbar in ipairs(hotbars) do
        local succeeded, content = pcall(table.to_xml, hotbar)
        if not succeeded then
            return nil, 'Unable to serialize hotbar XML: ' .. tostring(content)
        end
        serialized[index] = content
    end

    return serialized
end


local function write_hotbars(new_hotbar)
    local serialized, serialize_error = serialize_hotbars(new_hotbar)
    if serialized == nil then
        return nil, serialize_error
    end

    local addon_path = windower.addon_path
    return file_transaction.write({
        {path = addon_path .. storage.file.path, content = serialized[1]},
        {path = addon_path .. storage.job_default_file.path, content = serialized[2]},
        {path = addon_path .. storage.all_jobs_file.path, content = serialized[3]},
    }, filesystem)
end

-- setup storage for current player
function storage:setup(player)
    local sub_job = player.sub_job
    if (sub_job == nil) then
        sub_job = 'NOSUB'
    end
    self.filename = player.main_job .. '-' .. sub_job
    self.directory = player.server .. '/' .. player.name

    self.file = file.new('data/hotbar/' .. self.directory .. '/' .. self.filename .. '.xml')
    self.job_default_file = file.new('data/hotbar/' .. self.directory .. '/' .. player.main_job .. '-DEFAULT.xml')
    self.all_jobs_file = file.new('data/hotbar/' .. self.directory .. '/ALL-JOBS-DEFAULT.xml')
end

function split_hotbar(hotbar_to_split)
    -- For the "normal" hotbar file: e.g. DRG-SAM.xml
    local job_sub_hotbar = {}
    job_sub_hotbar.hotbar = {}

    -- For the "job" hotbar file: e.g. DRG-DEFAULT.xml
    local job_hotbar = {}
    job_hotbar.hotbar = {}

    -- For the "character" hotbar file: e.g. ALL-JOBS-DEFAULT.xml
    local all_jobs_hotbar = {}
    all_jobs_hotbar.hotbar = {}

    for environment, hb in pairs(hotbar_to_split.hotbar) do
        if (string.sub(environment, 1, 4) == 'all-') then
            all_jobs_hotbar.hotbar[environment] = hb
        elseif (string.sub(environment, 1, 4) == 'job-') then
            job_hotbar.hotbar[environment] = hb
        else
            job_sub_hotbar.hotbar[environment] = hb
        end
    end

    return job_sub_hotbar, job_hotbar, all_jobs_hotbar
end

-- store an hotbar in a new file
function storage:store_new_hotbar(new_hotbar)
    self.file:create_path()
    return write_hotbars(new_hotbar)
end

-- update filename according to jobs
function storage:update_filename(main, sub)
    self.filename = main .. '-' .. sub
    self.file = file.new('data/hotbar/' .. self.directory .. '/' .. self.filename .. '.xml')
    self.job_default_file = file.new('data/hotbar/' .. self.directory .. '/' .. main .. '-DEFAULT.xml')
    self.all_jobs_file = file.new('data/hotbar/' .. self.directory .. '/ALL-JOBS-DEFAULT.xml')
end

-- update file with hotbar
function storage:save_hotbar(new_hotbar)
    if not self.file:exists() then
        return nil, 'Hotbar file could not be found: ' .. self.file.path
    end

    return write_hotbars(new_hotbar)
end

return storage
