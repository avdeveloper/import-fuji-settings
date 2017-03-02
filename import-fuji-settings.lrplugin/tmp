local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrApplication = import 'LrApplication'

local logger = import 'LrLogger'( 'IncameraFujiRatingConverter' )
logger:enable( 'print' )
logger:info('-------------------- Execution start --------------------')

-- TODO: create a settings panel in plugin manager to set this value
local exiftoolPath
if (MAC_ENV) then
  exiftoolPath = '/usr/local/bin/exiftool'
else
  exiftoolPath = 'C:\\\Windows\\\exiftool.exe'
end

function main()
  local catalog = LrApplication.activeCatalog()
  local targetPhotos = catalog.targetPhotos
  for i, photo in ipairs(targetPhotos) do
    -- TODO: show some kind of progress bar and/or notification once the ratings are converted
    LrTasks.startAsyncTask(function()
      local filePath = photo.path
      local fileWithoutExtension = GetFilePathWithoutExtension(filePath);
      setRatingForJpgAndRaf(fileWithoutExtension)
    end)
  end
end

function GetFilePathWithoutExtension(url)
  return url:match("^([^.]+)")
end

function setRatingForJpgAndRaf(fileWithoutExtension)
  local jpgFile = GetJpgFile(fileWithoutExtension)

  if jpgFile then
    local rafFile = GetRafFile(fileWithoutExtension)
    local cmdToGetRating = getCmdForFetchingIncameraRating(jpgFile)
    setRating(jpgFile, cmdToGetRating)

    if rafFile then
      local xmpFile = fileWithoutExtension .. '.xmp'
      setRating(xmpFile, cmdToGetRating)
    end
  end
end

function GetJpgFile(fileWithoutExtension)
  -- TODO: make this work by ignoring letter case
  local supportedJpgFileExtensions = {'.JPG', '.jpg'}
  return GetFile(fileWithoutExtension, supportedJpgFileExtensions)
end

function GetRafFile(fileWithoutExtension)
  -- TODO: make this work by ignoring letter case
  local supportedRafFileExtensions = {'.RAF', '.raf'}
  return GetFile(fileWithoutExtension, supportedRafFileExtensions)
end

function GetFile(fileWithoutExtension, extensions)
  for i, extension in ipairs(extensions) do
    local fileWithExtension = fileWithoutExtension .. extension
		if LrFileUtils.exists(fileWithExtension) and LrFileUtils.isReadable(fileWithExtension) then
      logger:info('Found file: ', fileWithExtension)
      return fileWithExtension
    end
  end
end

function getCmdForFetchingIncameraRating(jpgFile)
  -- FIXME: this is not going to work on windows
  return exiftoolPath .. ' -rating ' .. jpgFile .. ' | grep -o "[^ ]*$"'
end

function setRating(file, cmdToGetRating)
  -- TODO: find a way to get the results of cmdToGetRating so we don't have to repeat/nest the bash statement
  logger:info('Setting rating for file: ', file)
  -- FIXME: this is not going to work on windows (nested bash command)
  LrTasks.execute(exiftoolPath .. ' -overwrite_original -rating=$('.. cmdToGetRating ..') ' .. file)
end

-- THIS FUNCTION DOES NOT WORK
-- LrTasks.execute does not return the output of exiftool
-- TODO: how to read output from LrTasks.execute?
function GetRatingFromFile(file)
  local cmd = exiftoolPath .. ' -rating ' .. file .. ' | grep -o "[^ ]*$"'
  local rating = LrTasks.execute(cmd)
  logger:info('Found rating: ', rating)
  return rating
end

main()
