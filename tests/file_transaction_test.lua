package.path = './?.lua;' .. package.path

local file_transaction = require('file_transaction')

local function assert_equal(expected, actual, message)
    if expected ~= actual then
        error((message or 'values differ') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
    end
end

local function new_adapter(initial_files)
    local adapter = {files = {}, fail_read = {}, fail_write = {}, fail_remove = {}, fail_rename = {}}
    for path, content in pairs(initial_files or {}) do
        adapter.files[path] = content
    end

    function adapter.exists(path)
        return adapter.files[path] ~= nil
    end

    function adapter.read(path)
        if adapter.fail_read[path] then
            return nil, 'simulated read failure'
        end
        return adapter.files[path]
    end

    function adapter.write(path, content)
        if adapter.fail_write[path] then
            return nil, 'simulated write failure'
        end
        adapter.files[path] = content
        return true
    end

    function adapter.remove(path)
        if adapter.fail_remove[path] then
            return nil, 'simulated remove failure'
        end
        adapter.files[path] = nil
        return true
    end

    function adapter.rename(source, destination)
        if adapter.fail_rename[source .. '>' .. destination] then
            return nil, 'simulated rename failure'
        end
        if adapter.files[source] == nil then
            return nil, 'source missing'
        end
        adapter.files[destination] = adapter.files[source]
        adapter.files[source] = nil
        return true
    end

    return adapter
end

local old_a = '<hotbar><default><name>Default</name></default></hotbar>'
local old_b = '<hotbar><job-default><name>Job Default</name></job-default></hotbar>'
local old_c = '<hotbar><all-jobs-default><name>All Jobs</name></all-jobs-default></hotbar>'
local new_a = '<hotbar><default><name>New Default</name></default></hotbar>'
local new_b = '<hotbar><job-default><name>New Job</name></job-default></hotbar>'
local new_c = '<hotbar><all-jobs-default><name>New All</name></all-jobs-default></hotbar>'
local entries = {
    {path = 'a.xml', content = new_a},
    {path = 'b.xml', content = new_b},
    {path = 'c.xml', content = new_c},
}

local adapter = new_adapter({['a.xml'] = old_a, ['b.xml'] = old_b, ['c.xml'] = old_c})
local saved, save_error = file_transaction.write(entries, adapter)
assert_equal(true, saved, save_error)
assert_equal(new_a, adapter.files['a.xml'], 'installs first file')
assert_equal(new_b, adapter.files['b.xml'], 'installs second file')
assert_equal(new_c, adapter.files['c.xml'], 'installs third file')
assert_equal(old_a, adapter.files['a.xml' .. file_transaction.BACKUP_SUFFIX], 'retains first backup')

adapter = new_adapter({['a.xml'] = old_a, ['b.xml'] = old_b, ['c.xml'] = old_c})
adapter.fail_write['b.xml' .. file_transaction.TEMP_SUFFIX] = true
saved = file_transaction.write(entries, adapter)
assert_equal(nil, saved, 'staging failure is reported')
assert_equal(old_a, adapter.files['a.xml'], 'staging failure preserves first original')
assert_equal(old_b, adapter.files['b.xml'], 'staging failure preserves second original')
assert_equal(old_c, adapter.files['c.xml'], 'staging failure preserves third original')

adapter = new_adapter({['a.xml'] = old_a, ['b.xml'] = old_b, ['c.xml'] = old_c})
adapter.fail_read['b.xml'] = true
saved = file_transaction.write(entries, adapter)
assert_equal(nil, saved, 'read failure is reported')
assert_equal(old_a, adapter.files['a.xml'], 'read failure preserves first original')
assert_equal(old_b, adapter.files['b.xml'], 'read failure preserves second original')

adapter = new_adapter({['a.xml'] = old_a, ['b.xml'] = old_b, ['c.xml'] = old_c})
saved = file_transaction.write({
    {path = 'a.xml', content = '<hotbar>\n</hotbar>\n'},
    {path = 'b.xml', content = new_b},
    {path = 'c.xml', content = new_c},
}, adapter)
assert_equal(nil, saved, 'empty replacement is rejected')
assert_equal(old_a, adapter.files['a.xml'], 'empty replacement preserves original')

adapter = new_adapter({['a.xml'] = old_a, ['b.xml'] = old_b, ['c.xml'] = old_c})
adapter.fail_rename['b.xml' .. file_transaction.TEMP_SUFFIX .. '>b.xml'] = true
saved = file_transaction.write(entries, adapter)
assert_equal(nil, saved, 'commit failure is reported')
assert_equal(old_a, adapter.files['a.xml'], 'rollback restores first original')
assert_equal(old_b, adapter.files['b.xml'], 'rollback restores second original')
assert_equal(old_c, adapter.files['c.xml'], 'rollback preserves third original')

adapter = new_adapter({
    ['a.xml'] = old_a,
    ['b.xml'] = old_b,
    ['c.xml'] = old_c,
    ['b.xml' .. file_transaction.BACKUP_SUFFIX] = 'older backup',
})
adapter.fail_remove['b.xml' .. file_transaction.BACKUP_SUFFIX] = true
saved = file_transaction.write(entries, adapter)
assert_equal(nil, saved, 'backup removal failure is reported')
assert_equal(old_a, adapter.files['a.xml'], 'backup failure rolls back first original')
assert_equal(old_b, adapter.files['b.xml'], 'backup failure preserves second original')
assert_equal(old_c, adapter.files['c.xml'], 'backup failure preserves third original')

print('file transaction tests passed')
