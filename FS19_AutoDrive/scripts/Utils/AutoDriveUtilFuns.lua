-- positive X -> left
-- negative X -> right
function AutoDrive.createWayPointRelativeToVehicle(vehicle, offsetX, offsetZ)
    local wayPoint = {}
    wayPoint.x, wayPoint.y, wayPoint.z = localToWorld(vehicle.components[1].node, offsetX, 0, offsetZ)
    return wayPoint
end

function AutoDrive.isTrailerInCrop(vehicle)
    local trailers, trailerCount = AutoDrive.getTrailersOf(vehicle)
    local trailer = trailers[trailerCount]
    local inCrop = false
    if trailer ~= nil then
        if trailer.ad == nil then
            trailer.ad = {}
        end
        ADSensor:handleSensors(trailer, dt)
        inCrop = trailer.ad.sensors.centerSensorFruit:pollInfo()
    end
    return inCrop
end

function AutoDrive.isVehicleOrTrailerInCrop(vehicle)
    return AutoDrive.isTrailerInCrop(vehicle) or vehicle.ad.sensors.centerSensorFruit:pollInfo()
end

function AutoDrive:checkIsConnected(toCheck, other)
	local isAttachedToMe = false
	if toCheck == nil or other == nil then
		return false
	end
	if toCheck.getAttachedImplements == nil then
		return false
	end

	for _, impl in pairs(toCheck:getAttachedImplements()) do
		if impl.object ~= nil then
			if impl.object == other then
				return true
			end

			if impl.object.getAttachedImplements ~= nil then
				isAttachedToMe = isAttachedToMe or AutoDrive:checkIsConnected(impl.object, other)
			end
		end
	end

	return isAttachedToMe
end

function AutoDrive.defineMinDistanceByVehicleType(vehicle)
    local min_distance = 1.8
    if
        vehicle.typeDesc == "combine" or vehicle.typeDesc == "harvester" or vehicle.typeName == "combineDrivable" or vehicle.typeName == "selfPropelledMower" or vehicle.typeName == "woodHarvester" or vehicle.typeName == "combineCutterFruitPreparer" or vehicle.typeName == "drivableMixerWagon" or
            vehicle.typeName == "cottonHarvester" or
            vehicle.typeName == "pdlc_claasPack.combineDrivableCrawlers"
     then
        min_distance = 6
    elseif vehicle.typeDesc == "telehandler" or vehicle.spec_crabSteering ~= nil then --If vehicle has 4 steering wheels like xerion or hardi self Propelled sprayer then also min_distance = 3;
        min_distance = 3
    elseif vehicle.typeDesc == "truck" then
        min_distance = 3
    end
    -- If vehicle is quadtrack then also min_distance = 6;
    if vehicle.spec_articulatedAxis ~= nil and vehicle.spec_articulatedAxis.rotSpeed ~= nil then
        min_distance = 6
    end
    return min_distance
end

function AutoDrive.getVehicleMaxSpeed(vehicle)
	-- 255 is the max value to prevent errors with MP sync
	if vehicle ~= nil and vehicle.spec_motorized ~= nil and vehicle.spec_motorized.motor ~= nil then
		local motor = vehicle.spec_motorized.motor
		return math.min(motor:getMaximumForwardSpeed() * 3.6, 255)
	end
	return 255
end

function AutoDrive.renameDriver(vehicle, name, sendEvent)
	if name:len() > 1 and vehicle ~= nil and vehicle.ad ~= nil then
		if sendEvent == nil or sendEvent == true then
			-- Propagating driver rename all over the network
			AutoDriveRenameDriverEvent.sendEvent(vehicle, name)
		else
			vehicle.ad.stateModule:setName(name)
		end
	end
end

function AutoDrive.hasToRefuel(vehicle)
    local spec = vehicle.spec_motorized

    if spec.consumersByFillTypeName ~= nil and spec.consumersByFillTypeName.diesel ~= nil and spec.consumersByFillTypeName.diesel.fillUnitIndex ~= nil then
        return vehicle:getFillUnitFillLevelPercentage(spec.consumersByFillTypeName.diesel.fillUnitIndex) <= AutoDrive.REFUEL_LEVEL
    end
    
    return false;
end

function AutoDrive.combineIsTurning(combine)
    local cpIsTurning = combine.cp ~= nil and (combine.cp.isTurning or (combine.cp.turnStage ~= nil and combine.cp.turnStage > 0))
    local cpIsTurningTwo = combine.cp ~= nil and combine.cp.driver and (combine.cp.driver.turnIsDriving or (combine.cp.driver.fieldworkState ~= nil and combine.cp.driver.fieldworkState == combine.cp.driver.states.TURNING))
    local aiIsTurning = (combine.getAIIsTurning ~= nil and combine:getAIIsTurning() == true)
    local combineSteering = combine.rotatedTime ~= nil and (math.deg(combine.rotatedTime) > 30);
    local combineIsTurning = cpIsTurning or cpIsTurningTwo or aiIsTurning or combineSteering
    
    if ((combine:getIsBufferCombine() and combine.ad.noTurningTimer:done()) or (combine.ad.driveForwardTimer:done() and (not combine:getIsBufferCombine()))) and (not combineIsTurning) then
        return false
    end
    return true
end

function AutoDrive.pointIsBetweenTwoPoints(x, z, startX, startZ, endX, endZ)
    local xInside = (startX >= x and endX <= x) or (startX <= x and endX >= x)
    local zInside = (startZ >= z and endZ <= z) or (startZ <= z and endZ >= z)
    return xInside and zInside
end

function AutoDrive.semanticVersionToValue(versionString)
    local codes = versionString:split(".")
    local value = 0
    if codes ~= nil then
        for i, code in ipairs(codes) do
            local subCodes = code:split("-")
            if subCodes ~= nil and subCodes[1] ~= nil then
                value = value*10 + tonumber(subCodes[1])
                if subCodes[2] ~= nil then
                    value = value + (tonumber(subCodes[2])/1000)
                end
            end            
        end
    end

    return value
end