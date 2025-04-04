// Handles the routes for the authentication
const express = require("express");
const router = express.Router();
require("dotenv").config();
const ClubLeader = require("../models/ClubLeaderModel");
const User = require("../models/NormalUserModel");
const jwt = require("jsonwebtoken");
const SECRET_KEY = process.env.JWT_SECRET || "777";
const bcrypt = require("bcrypt");

router.post("/register-user", async (req, res) => {
  try {
    const { name, username, email, password } = req.body;
    if (!name || !username || !password || !email) {
      return res.status(400).json({ error: "Please provide all the details" });
    }

    // Check if the user already exists in NormalUserModel
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: "User already exists" });
    }

    // Create a new normal user
    const newUser = new User({ name, username, email, password });
    await newUser.save();

    res.status(201).json({ message: "User registration successful" });
  } catch (error) {
    console.error("Registration error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

router.post("/login-clubleader", async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log("Login request received:", req.body);

    // Find user by username
    const clubLeader = await ClubLeader.findOne({ username });
    if (!clubLeader) {
      return res.status(400).json({ error: "User not found" });
    }

    console.log("User found:", clubLeader);

    // Compare hashed password using bcrypt
    const isMatch = await bcrypt.compare(password, clubLeader.password);

    console.log("Password Match:", isMatch);

    if (!isMatch) {
      return res.status(400).json({ error: "Incorrect Password" });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        id: clubLeader._id,
        username: clubLeader.username,
        role: "clubLeader",
        clubName: clubLeader.clubName,
      },
      SECRET_KEY,
      { expiresIn: "7d" }
    );

    console.log("Generated Token:", token);
    res.status(200).json({ token });
  } catch (error) {
    console.error("Login Error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

router.post("/login-user", async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log("Login request received:", req.body);

    // Check for username
    const user = await User.findOne({ username });

    if (!user) {
      return res.status(400).json({ error: "User not found" });
    }

    console.log("User found:", user);

    // Compare hashed password using bcrypt
    const isMatch = await bcrypt.compare(password, user.password);

    console.log("Password Match:", isMatch);

    if (!isMatch) {
      return res.status(400).json({ error: "Incorrect Password" });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        id: user._id,
        username: user.username,
        clubName: user.clubName,
        role: "student",
      },
      SECRET_KEY,
      { expiresIn: "7d" }
    );

    console.log("Generated Token:", token);
    res.status(200).json({ token });
  } catch (error) {
    console.error("Login Error:", error);
    res.status(500).json({ error: "Server error" });
  }
});

//get user det
router.get("/user", async (req, res) => {
  try {
    const token = req.headers.authorization?.split(" ").at(1);
    if (!token) {
      return res.status(401).json({ error: "Unauthorized, no token provided" });
    }

    const decoded = jwt.verify(token, SECRET_KEY);
    const userId = decoded.id;

    const user = await User.findById(userId).select("-password");
    if (!user) {
      return res.status(404).json({ error: "User not found" });
    }

    return res.status(200).json(user);
  } catch (e) {
    return res.status(500).json({ error: `Server error` });
  }
});

//get clubleader det
router.get("/clubleader", async (req, res) => {
  try {
    const token = req.headers.authorization?.split(" ").at(1);
    if (!token) {
      return res.status(401).json({ error: "Unauthorized, no token provided" });
    }

    const decoded = jwt.verify(token, SECRET_KEY);
    const clubLeaderId = decoded.id;

    const clubLeader = await ClubLeader.findById(clubLeaderId).select(
      "-password"
    );
    if (!clubLeader) {
      return res.status(404).json({ error: "Clubleader not found" });
    }

    return res.status(200).json(clubLeader);
  } catch (e) {
    return res.status(500).json({ error: `Server error` });
  }
});

module.exports = router;
