package com.minimalism.focus.ui

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.CountDownTimer
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.minimalism.focus.enforcement.FocusPolicyStore

class BlockActivity : Activity() {
    private var targetPackage: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        targetPackage = intent.getStringExtra("packageName") ?: ""
        val reason = intent.getStringExtra("reason") ?: "You've reached your limit. Continue tomorrow."
        val overridesRemaining = intent.getIntExtra("overridesRemaining", 0)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.rgb(16, 26, 22))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        root.addView(title("Focus Lock", 30, Color.rgb(216, 254, 226)))
        root.addView(label(reason, 18, Color.rgb(231, 238, 233)))
        root.addView(label("Emergency unlocks left today: $overridesRemaining", 15, Color.rgb(191, 211, 197)))

        val overrideButton = Button(this).apply {
            text = "Unlock in 15s"
            isEnabled = false
        }
        val homeButton = Button(this).apply {
            text = "Return to home"
        }

        root.addView(overrideButton, fullWidthParams(top = 24))
        root.addView(homeButton, fullWidthParams(top = 8))
        setContentView(root)

        object : CountDownTimer(15000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                overrideButton.text = "Unlock in ${millisUntilFinished / 1000}s"
            }

            override fun onFinish() {
                overrideButton.text = "Use emergency override"
                overrideButton.isEnabled = true
            }
        }.start()

        overrideButton.setOnClickListener {
            val allowed = FocusPolicyStore.consumeOverride(this, targetPackage)
            if (!allowed) {
                Toast.makeText(this, "No overrides remaining today.", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            FocusPolicyStore.enqueueEvent(
                context = this,
                eventType = "override",
                packageName = targetPackage,
                metadata = mapOf("graceMinutes" to 5)
            )
            Toast.makeText(this, "Unlocked for 5 minutes.", Toast.LENGTH_SHORT).show()
            reopenBlockedAppOrHome()
            finish()
        }

        homeButton.setOnClickListener {
            goHome()
            finish()
        }
    }

    override fun onBackPressed() {
        goHome()
        finish()
    }

    private fun reopenBlockedAppOrHome() {
        val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launchIntent)
        } else {
            goHome()
        }
    }

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        })
    }

    private fun title(text: String, size: Int, color: Int): TextView {
        return label(text, size, color).apply {
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
    }

    private fun label(text: String, size: Int, color: Int): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = size.toFloat()
            setTextColor(color)
            gravity = Gravity.CENTER
            setPadding(0, 10, 0, 10)
        }
    }

    private fun fullWidthParams(top: Int): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = top
        }
    }
}
