// Jolt Physics Library (https://github.com/jrouwe/JoltPhysics)
// SPDX-FileCopyrightText: 2021 Jorrit Rouwe
// SPDX-License-Identifier: MIT

#pragma once

#include <Tests/Vehicle/VehicleTest.h>
#include <Jolt/Physics/Constraints/SixDOFConstraint.h>

// This test shows how a vehicle could be made with the SixDOF constraint.
class VehicleSixDOFTest : public VehicleTest
{
public:
	JPH_DECLARE_RTTI_VIRTUAL(JPH_NO_EXPORT, VehicleSixDOFTest)

	// See: Test
	virtual void			Initialize() override;
	virtual void			ProcessInput(const ProcessInputParams &inParams) override;
	virtual void			PrePhysicsUpdate(const PreUpdateParams &inParams) override;
	virtual void			SaveInputState(StateRecorder &inStream) const override;
	virtual void			RestoreInputState(StateRecorder &inStream) override;

	virtual void			GetInitialCamera(CameraState &ioState) const override;
	virtual RMat44			GetCameraPivot(float inCameraHeading, float inCameraPitch) const override;

private:
	static constexpr float	cMaxSteeringAngle = DegreesToRadians(30);

	using EAxis = SixDOFConstraintSettings::EAxis;

	enum class EWheel : int
	{
		LeftFront,
		RightFront,
		LeftRear,
		RightRear,
		Num,
	};

	static inline bool		sIsFrontWheel(EWheel inWheel)		{ return inWheel == EWheel::LeftFront || inWheel == EWheel::RightFront; }
	static inline bool		sIsLeftWheel(EWheel inWheel)		{ return inWheel == EWheel::LeftFront || inWheel == EWheel::LeftRear; }

	Body *					mCarBody;
	Ref<SixDOFConstraint>	mWheels[int(EWheel::Num)];

	// Player input
	float					mSteeringAngle = 0.0f;
	float					mSpeed = 0.0f;
};
