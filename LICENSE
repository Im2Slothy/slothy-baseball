SlothyBaseball = SlothyBaseball or {}

function SlothyBaseball.Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function SlothyBaseball.Debug(message)
    if Config.Debug then
        print(('[slothy-baseball] %s'):format(message))
    end
end

