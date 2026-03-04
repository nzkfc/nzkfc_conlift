Config = {}

Config.LiftSpeed           = 3.5 -- Suggest max speed 12
Config.InteractionDistance = 2.0

Config.Levels = {
    {
        name    = "Bottom",
        coords  = vector3(-158.773224, -942.2636, 31.38526),
        enabled = true,
    },
    {
        name    = "Level 1",
        coords  = vector3(-158.773224, -942.2636, 40.5976067),
        enabled = true,
    },
	-- Note: The true level 2 has invisible collision, so you can't walk into it.
    {
        name    = "Level 2",
        coords  = vector3(-158.773224, -942.2636, 115.496483),
        enabled = true,
    },
    {
        name    = "Level 3",
        coords  = vector3(-158.773224, -942.2636, 255.513),
        enabled = true,
    },
    {
        name    = "Level 4",
        coords  = vector3(-158.773224, -942.2636, 270.529663),
        enabled = true,
    },
}

Config.CallButtons = { -- Leave as is
    
	{ levelIdx = 1, pos = vec4(-161.98, -941.66, 28.3, 161.0)  }, -- Ground
    { levelIdx = 2, pos = vec4(-155.95, -943.55, 38.26, 340.52)  },
    { levelIdx = 3, pos = vec4(-155.95, -943.55, 113.14, 340.52)  },
    { levelIdx = 4, pos = vec4(-155.95, -943.55, 253.12, 340.52)   },
    { levelIdx = 5, pos = vec4(-155.95, -943.55, 268.13, 340.52)  }, -- Top
}

Config.LiftRotation        = { x = 0.0, y = 0.0, z = 0.1736481, w = 0.9848078 } -- Leave as is