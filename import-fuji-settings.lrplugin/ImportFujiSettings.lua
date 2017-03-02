-- Import dependencies
local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

-- Set up the logger for debugging
local LrLogger = import 'LrLogger'
local logger = LrLogger 'ImportFujiSettings'
logger:enable 'logfile'
logger:info 'Importing Fuji settings for selected photos...'

-- Global variables
local cmdToGetMetadata = getPluginPath('/bin/exiftool') .. ' -csv -Rating -FilmMode -ShadowTone -HighlightTone -WhiteBalance -NoiseReduction -Saturation '

-- This is the start of the core execution
function main()
    local catalog = LrApplication.activeCatalog()

    for i, photo in ipairs(catalog.targetPhotos) do
        LrTasks.startAsyncTask(function ()
            -- get exif data from RAW File
            local metadataInCSV = getMetadataFromFile(photo.path)

            if metadataInCSV ~= nil then
                -- TODO remove; it's only here for debugging
                for i,metadata in pairs(metadataInCSV) do
                    logger:info(i .. ': ' .. metadata)
                end

                -- TODO use exiftool to write to the XMP 
            end
        end)
    end
end

-- Return the metadata at a given RAW file
-- @param {String} path to the RAW file
-- @return {table|nil} containing metadata fetched from RAW file
function getMetadataFromFile(path)
    local metadata = os.capture(cmdToGetMetadata .. path, true)

    if metadata ~= nil then
        metadata = split(metadata, "\n")[2] -- split csv by lines and ignore the header row
        metadata = split(metadata, ',') -- split row by comma so we get an array of metadata

        return {
            Path = metadata[1],
            Rating = metadata[2],
            CameraProfile = metadata[3], -- translate to Adobe's naming convention accordingly
            ShadowTone = metadata[4], -- TODO change shadowtone to whichever name Adobe uses for shadow level and translate to appropriate value
            HighlightTone = metadata[5], -- TODO change key name according to Adobe and translate adjustment level value of highlights accordingly
            -- skip for nowwhiteBalance = metadata[6],
            -- skip for nownoiseReduction = metadata[7],
            Saturation = metadata[8] -- change accordingly to adobe
        }
    else
        logger:error('Could not find metadata for RAW file at: ' .. path)
        return nil
    end
end

-- Executes a command and returns the output
-- @param {String} cmd to execute
-- @param {Boolean} raw set to true to ignore whitespace
-- @return {String} output from command
function os.capture(cmd, raw)
   local f = assert(io.popen(cmd, 'r'))
   local s = assert(f:read('*a'))
   f:close()

   if raw then return s end

   s = string.gsub(s, '^%s+', '')
   s = string.gsub(s, '%s+$', '')
   s = string.gsub(s, '[\n\r]+', ' ')
   return s
end

-- Returns a path relative to the plugin
-- @param {String} tail is the path relative to plugin
-- @return {String}
function getPluginPath(tail)
    return _PLUGIN.path .. tail
end

-- Splits a string based on a delimiter
-- @param {String} str the part we want to split
-- @param {String} delim is the delimiter
-- @return {table} array of parts separated by the delimiter
function split(str, delim)
    local result,pat,lastPos = {},"(.-)" .. delim .. "()",1
    for part, pos in string.gfind(str, pat) do
        table.insert(result, part); lastPos = pos
    end
    table.insert(result, string.sub(str, lastPos))
    return result
end

-- Execute
main()
