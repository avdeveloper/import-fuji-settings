-- Import dependencies
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

-- Set up the logger for debugging
local LrLogger = import 'LrLogger'
local logger = LrLogger 'ImportFujiSettings'
logger:enable 'logfile'
logger:info 'Importing Fuji settings for selected photos...'

-- Global variables
local cmdToGetMetadata = _PLUGIN.path .. '/bin/exiftool -T -fast -FileName -Rating -Saturation -FilmMode -ShadowTone -HighlightTone -WhiteBalance -NoiseReduction -Color '
local exiftool = _PLUGIN.path .. '/bin/exiftool '

-- This is the start of the core execution
function main()
    local catalog = LrApplication.activeCatalog()

    LrFunctionContext.postAsyncTaskWithContext('importFujiSettings', function (context)
        local numProcessed = 0;
        local totalPhotos = #catalog.targetPhotos;
        local progress = LrProgressScope({
            title = 'Importing Fuji settings for ' .. totalPhotos .. ' photos...',
            functionContext = context
        })

        for i, photo in ipairs(catalog.targetPhotos) do
            -- get exif data from RAW File
            local metadataInCSV = getMetadataFromFile(photo.path)
            local cmdToSetMetadata = exiftool .. '-Rating="' .. metadataInCSV['Rating'] .. '" -CameraProfile="' .. metadataInCSV['CameraProfile'] .. '" ' .. string.gsub(photo.path, 'RAF', 'xmp')
            logger:info(cmdToSetMetadata)
            local result = LrTasks.execute(cmdToSetMetadata)
            numProcessed = numProcessed + 1
            progress:setPortionComplete(numProcessed, totalPhotos)

            if progress:isCanceled() then break end
        end

        progress:done()
    end)
end

-- Return the metadata at a given RAW file
-- @param {String} path to the RAW file
-- @return {table|nil} containing metadata fetched from RAW file
function getMetadataFromFile(path)
    local metadata = os.capture(cmdToGetMetadata .. path, true)

    if metadata ~= nil then
        -- metadata = split(metadata, "\n")[2] -- split csv by lines and ignore the header row
        metadata = split(metadata, '\t') -- split row by comma so we get an array of metadata
        logger:debug('metadata: ' .. metadata[1] .. ' and ' .. metadata[2] .. ' and ' .. metadata[3] .. ' and ' .. metadata[4] .. ' and ' .. metadata[5])

        return {
            Path = metadata[1],
            Rating = metadata[2],
            CameraProfile = translateToCameraProfile(metadata[3], metadata[4]),
            ShadowTone = metadata[5], -- TODO change shadowtone to whichever name Adobe uses for shadow level and translate to appropriate value
            HighlightTone = metadata[6], -- TODO change key name according to Adobe and translate adjustment level value of highlights accordingly
            -- skip for now WhiteBalance = metadata[7],
            -- skip for now NoiseReduction = metadata[8],
            Saturation = metadata[9] -- change accordingly to adobe
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

-- Translate the name from Fuji convention to Adobe Camera Setting
-- @param {String} saturation color profile is stored here for monochrome
-- @param {String} filmMode name of the film simulation
-- @return {String} matching setting in ACS convention
function translateToCameraProfile(saturation, filmMode)
    logger:debug(saturation .. ' and ' .. filmMode)
    local cameraProfile = 'Camera '

    if string.find(saturation, 'Acros') or string.find(saturation, 'B&W') then
        logger:debug('it is monochrome')

        -- ACROS or MONOCHROME?
        if string.find(saturation, 'Acros') then
            cameraProfile = cameraProfile .. 'ACROS'
        else
            cameraProfile = cameraProfile .. 'MONOCHROME'
        end

        -- with or without filter?
        if string.find(saturation, 'Yellow') then
            cameraProfile = cameraProfile .. '+Ye FILTER'
        elseif string.find(saturation, 'Red') then
            cameraProfile = cameraProfile .. '+R FILTER'
        elseif string.find(saturation, 'Green') then
            cameraProfile = cameraProfile .. '+G FILTER'
        end
    else -- it is color
        logger:debug('it is color')
        if string.find(filmMode, 'Velvia') then
            cameraProfile = cameraProfile .. 'Velvia/VIVID'
        elseif string.find(filmMode, 'Astia') then
            cameraProfile = cameraProfile .. 'ASTIA/SOFT'
        elseif string.find(filmMode, 'Classic Chrome') then
            cameraProfile = cameraProfile .. 'CLASSIC CHROME'
        elseif string.find(filmMode, 'Neg. Hi') then
            cameraProfile = cameraProfile .. 'Pro Neg. Hi'
        elseif string.find(filmMode, 'Neg. Std') then
            cameraProfile = cameraProfile .. 'Pro Neg. Std'
        else 
            cameraProfile = cameraProfile .. 'PROVIA/STANDARD'
        end
    end

    logger:debug('result is ' .. cameraProfile)
    return cameraProfile
end

-- Execute
main()
