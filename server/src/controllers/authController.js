const prisma = require("../config/db");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { sendOtp, verifyOtp } = require("../services/otpService");

const issueToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, { expiresIn: "7d" });

// Strips fields that must never leave the server: password hash and the
// SMS HMAC signing key. Always send the response through this before
// returning a `user` object to a client.
const sanitizeUser = (user) => {
  if (!user) return user;
  const { password, sms_secret_key, ...safeUser } = user;
  return safeUser;
};

const registerUser = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email },
          ...(phone ? [{ phone }] : []),
        ],
      },
    });

    if (existingUser) {
      return res.status(400).json({ message: "User with this email or phone already exists" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
        phone,
        wallet: {
          create: {
            balance: 0,
            locked_balance: 0,
          },
        },
      },
      include: { wallet: true },
    });

    const token = issueToken(user.id);

    res.status(201).json({ message: "User registered successfully", token, user: sanitizeUser(user) });
  } catch (error) {
    console.error("REGISTER ERROR:", error);
    res.status(500).json({ message: "Server Error" });
  }
};

const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await prisma.user.findUnique({
      where: { email },
      include: { wallet: true },
    });

    if (!user) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const isPasswordCorrect = await bcrypt.compare(password, user.password);

    if (!isPasswordCorrect) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = issueToken(user.id);

    res.status(200).json({ message: "Login successful", token, user: sanitizeUser(user) });
  } catch (error) {
    console.error("LOGIN ERROR:", error);
    res.status(500).json({ message: "Server Error" });
  }
};

const getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { wallet: true },
    });

    res.status(200).json(sanitizeUser(user));
  } catch (error) {
    console.error("GET PROFILE ERROR:", error);
    res.status(500).json({ message: "Server Error" });
  }
};

const sendLoginOtp = async (req, res) => {
  try {
    const { phone } = req.body;
    const result = await sendOtp(phone);

    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    const payload = { message: result.message, phone: result.phone };
    if (result.devOtp) {
      payload.devOtp = result.devOtp;
    }

    res.status(200).json(payload);
  } catch (error) {
    console.error("SEND OTP ERROR:", error);
    res.status(500).json({ message: "Failed to send OTP" });
  }
};

const verifyLoginOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;
    const result = await verifyOtp(phone, otp);

    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    const token = issueToken(result.user.id);

    res.status(200).json({
      message: "Login successful",
      token,
      user: sanitizeUser(result.user),
    });
  } catch (error) {
    console.error("VERIFY OTP ERROR:", error);
    res.status(500).json({ message: "Failed to verify OTP" });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getProfile,
  sendLoginOtp,
  verifyLoginOtp,
};
