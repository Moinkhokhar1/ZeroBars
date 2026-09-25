const express = require("express");
const prisma = require("../config/db");
const { normalizePhone } = require("../utils/phoneUtils");
const router = express.Router();

const {
  registerUser,
  loginUser,
  getProfile,
  sendLoginOtp,
  verifyLoginOtp,
} = require("../controllers/authController");

const authMiddleware = require("../middleware/authMiddleware");

router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/send-otp", sendLoginOtp);
router.post("/verify-otp", verifyLoginOtp);
router.get("/profile", authMiddleware, getProfile);
router.get("/users/by-phone/:phone", authMiddleware, async (req, res) => {
  try {
    const phone = normalizePhone(req.params.phone.trim());

    if (!phone) {
      return res.status(400).json({ message: "Invalid phone number" });
    }

    const user = await prisma.user.findUnique({
      where: { phone },
      select: {
        id: true,
        name: true,
        phone: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    res.status(200).json(user);
  } catch (error) {
    console.log("FIND USER ERROR:", error);
    res.status(500).json({
      message: "Server Error",
    });
  }
});
router.get("/users/by-id/:id", authMiddleware, async (req, res) => {
  try {
    const userId = req.params.id.trim();

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        phone: true,
      },
    });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    return res.status(200).json(user);
  } catch (error) {
    console.error("FIND USER BY ID ERROR:", error);

    return res.status(500).json({
      message: "Server Error",
    });
  }
});

module.exports = router;