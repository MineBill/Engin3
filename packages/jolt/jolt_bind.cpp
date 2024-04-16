

#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

#include "jolt_bind.h"

#ifdef __cplusplus
}
#endif
// The Jolt headers don't include Jolt.h. Always include Jolt.h before including any other Jolt header.
// You can use Jolt.h in your precompiled header to speed up compilation.
#include <Jolt/Jolt.h>

// Jolt includes
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/Memory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Body/BodyActivationListener.h>
#include <Jolt/Jolt.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Core/Memory.h>
#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/EPhysicsUpdateError.h>
#include <Jolt/Physics/Collision/NarrowPhaseQuery.h>
#include <Jolt/Physics/Collision/CollideShape.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Collision/Shape/TriangleShape.h>
#include <Jolt/Physics/Collision/Shape/CapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/TaperedCapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/CylinderShape.h>
#include <Jolt/Physics/Collision/Shape/ConvexHullShape.h>
#include <Jolt/Physics/Collision/Shape/HeightFieldShape.h>
#include <Jolt/Physics/Collision/Shape/MeshShape.h>
#include <Jolt/Physics/Collision/Shape/RotatedTranslatedShape.h>
#include <Jolt/Physics/Collision/Shape/ScaledShape.h>
#include <Jolt/Physics/Collision/Shape/OffsetCenterOfMassShape.h>
#include <Jolt/Physics/Collision/Shape/StaticCompoundShape.h>
#include <Jolt/Physics/Collision/Shape/MutableCompoundShape.h>
#include <Jolt/Physics/Collision/PhysicsMaterial.h>
#include <Jolt/Physics/Constraints/FixedConstraint.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Body/BodyActivationListener.h>
#include <Jolt/Physics/Body/BodyLock.h>
#include <Jolt/Physics/Body/BodyManager.h>
#include <Jolt/Physics/Body/BodyFilter.h>
#include <Jolt/Physics/Character/Character.h>
#include <Jolt/Physics/Character/CharacterVirtual.h>

// STL includes
#include <iostream>
#include <cstdarg>
#include <thread>
#include <cassert>
using namespace JPH;

// If you want your code to compile using single or double precision write 0.0_r to get a Real value that compiles to double or float depending if JPH_DOUBLE_PRECISION is set or not.
using namespace JPH::literals;

// We're also using STL classes in this example
using namespace std;


#define ENSURE_TYPE(o, t) \
    assert(o != nullptr); \
    assert(reinterpret_cast<const JPH::SerializableObject *>(o)->CastTo(JPH_RTTI(t)) != nullptr)

#define FN(name) static auto name

FN(toJph)(JOLT_BodyID in) { return JPH::BodyID(in); }
FN(toJpc)(JPH::BodyID in) { return in.GetIndexAndSequenceNumber(); }

FN(toJpc)(const JPH::Body *in) { assert(in); return reinterpret_cast<const JOLT_Body *>(in); }
FN(toJph)(const JOLT_Body *in) { assert(in); return reinterpret_cast<const JPH::Body *>(in); }
FN(toJpc)(JPH::Body *in) { assert(in); return reinterpret_cast<JOLT_Body *>(in); }
FN(toJph)(JOLT_Body *in) { assert(in); return reinterpret_cast<JPH::Body *>(in); }

FN(toJph)(const JOLT_PhysicsMaterial *in) { return reinterpret_cast<const JPH::PhysicsMaterial *>(in); }
FN(toJpc)(const JPH::PhysicsMaterial *in) { return reinterpret_cast<const JOLT_PhysicsMaterial *>(in); }

FN(toJph)(const JOLT_ShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ShapeSettings);
    return reinterpret_cast<const JPH::ShapeSettings *>(in);
}
FN(toJph)(JOLT_ShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ShapeSettings);
    return reinterpret_cast<JPH::ShapeSettings *>(in);
}
FN(toJpc)(const JPH::ShapeSettings *in) { assert(in); return reinterpret_cast<const JOLT_ShapeSettings *>(in); }
FN(toJpc)(JPH::ShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_ShapeSettings *>(in); }

FN(toJph)(const JOLT_BoxShapeSettings *in) {
    ENSURE_TYPE(in, JPH::BoxShapeSettings);
    return reinterpret_cast<const JPH::BoxShapeSettings *>(in);
}
FN(toJph)(JOLT_BoxShapeSettings *in) {
    ENSURE_TYPE(in, JPH::BoxShapeSettings);
    return reinterpret_cast<JPH::BoxShapeSettings *>(in);
}
FN(toJpc)(JPH::BoxShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_BoxShapeSettings *>(in); }

FN(toJph)(const JOLT_SphereShapeSettings *in) {
    ENSURE_TYPE(in, JPH::SphereShapeSettings);
    return reinterpret_cast<const JPH::SphereShapeSettings *>(in);
}
FN(toJph)(JOLT_SphereShapeSettings *in) {
    ENSURE_TYPE(in, JPH::SphereShapeSettings);
    return reinterpret_cast<JPH::SphereShapeSettings *>(in);
}
FN(toJpc)(JPH::SphereShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_SphereShapeSettings *>(in); }

FN(toJph)(const JOLT_TriangleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::TriangleShapeSettings);
    return reinterpret_cast<const JPH::TriangleShapeSettings *>(in);
}
FN(toJph)(JOLT_TriangleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::TriangleShapeSettings);
    return reinterpret_cast<JPH::TriangleShapeSettings *>(in);
}
FN(toJpc)(JPH::TriangleShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_TriangleShapeSettings *>(in); }

FN(toJph)(const JOLT_CapsuleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::CapsuleShapeSettings);
    return reinterpret_cast<const JPH::CapsuleShapeSettings *>(in);
}
FN(toJph)(JOLT_CapsuleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::CapsuleShapeSettings);
    return reinterpret_cast<JPH::CapsuleShapeSettings *>(in);
}
FN(toJpc)(JPH::CapsuleShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_CapsuleShapeSettings *>(in); }

FN(toJph)(const JOLT_TaperedCapsuleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::TaperedCapsuleShapeSettings);
    return reinterpret_cast<const JPH::TaperedCapsuleShapeSettings *>(in);
}
FN(toJph)(JOLT_TaperedCapsuleShapeSettings *in) {
    ENSURE_TYPE(in, JPH::TaperedCapsuleShapeSettings);
    return reinterpret_cast<JPH::TaperedCapsuleShapeSettings *>(in);
}
FN(toJpc)(JPH::TaperedCapsuleShapeSettings *in) {
    assert(in); return reinterpret_cast<JOLT_TaperedCapsuleShapeSettings *>(in);
}

FN(toJph)(const JOLT_CylinderShapeSettings *in) {
    ENSURE_TYPE(in, JPH::CylinderShapeSettings);
    return reinterpret_cast<const JPH::CylinderShapeSettings *>(in);
}
FN(toJph)(JOLT_CylinderShapeSettings *in) {
    ENSURE_TYPE(in, JPH::CylinderShapeSettings);
    return reinterpret_cast<JPH::CylinderShapeSettings *>(in);
}
FN(toJpc)(JPH::CylinderShapeSettings *in) { assert(in); return reinterpret_cast<JOLT_CylinderShapeSettings *>(in); }

FN(toJph)(const JOLT_ConvexHullShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ConvexHullShapeSettings);
    return reinterpret_cast<const JPH::ConvexHullShapeSettings *>(in);
}
FN(toJph)(JOLT_ConvexHullShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ConvexHullShapeSettings);
    return reinterpret_cast<JPH::ConvexHullShapeSettings *>(in);
}
FN(toJpc)(JPH::ConvexHullShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_ConvexHullShapeSettings *>(in);
}

FN(toJph)(const JOLT_HeightFieldShapeSettings *in) {
    ENSURE_TYPE(in, JPH::HeightFieldShapeSettings);
    return reinterpret_cast<const JPH::HeightFieldShapeSettings *>(in);
}
FN(toJph)(JOLT_HeightFieldShapeSettings *in) {
    ENSURE_TYPE(in, JPH::HeightFieldShapeSettings);
    return reinterpret_cast<JPH::HeightFieldShapeSettings *>(in);
}
FN(toJpc)(JPH::HeightFieldShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_HeightFieldShapeSettings *>(in);
}

FN(toJph)(const JOLT_MeshShapeSettings *in) {
    ENSURE_TYPE(in, JPH::MeshShapeSettings);
    return reinterpret_cast<const JPH::MeshShapeSettings *>(in);
}
FN(toJph)(JOLT_MeshShapeSettings *in) {
    ENSURE_TYPE(in, JPH::MeshShapeSettings);
    return reinterpret_cast<JPH::MeshShapeSettings *>(in);
}
FN(toJpc)(JPH::MeshShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_MeshShapeSettings *>(in);
}

FN(toJph)(const JOLT_ConvexShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ConvexShapeSettings);
    return reinterpret_cast<const JPH::ConvexShapeSettings *>(in);
}
FN(toJph)(JOLT_ConvexShapeSettings *in) {
    ENSURE_TYPE(in, JPH::ConvexShapeSettings);
    return reinterpret_cast<JPH::ConvexShapeSettings *>(in);
}

FN(toJpc)(JPH::RotatedTranslatedShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_DecoratedShapeSettings *>(in);
}
FN(toJpc)(JPH::ScaledShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_DecoratedShapeSettings *>(in);
}
FN(toJpc)(JPH::OffsetCenterOfMassShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_DecoratedShapeSettings *>(in);
}
FN(toJph)(JOLT_DecoratedShapeSettings *in) {
    ENSURE_TYPE(in, JPH::DecoratedShapeSettings);
    return reinterpret_cast<JPH::DecoratedShapeSettings *>(in);
}

FN(toJpc)(JPH::StaticCompoundShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_CompoundShapeSettings *>(in);
}
FN(toJpc)(JPH::MutableCompoundShapeSettings *in) {
    assert(in);
    return reinterpret_cast<JOLT_CompoundShapeSettings *>(in);
}
FN(toJph)(JOLT_CompoundShapeSettings *in) {
    ENSURE_TYPE(in, JPH::CompoundShapeSettings);
    return reinterpret_cast<JPH::CompoundShapeSettings *>(in);
}

FN(toJph)(const JOLT_ConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::ConstraintSettings);
    return reinterpret_cast<const JPH::ConstraintSettings *>(in);
}
FN(toJph)(JOLT_ConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::ConstraintSettings);
    return reinterpret_cast<JPH::ConstraintSettings *>(in);
}
FN(toJpc)(const JPH::ConstraintSettings *in) { assert(in); return reinterpret_cast<const JOLT_ConstraintSettings *>(in); }
FN(toJpc)(JPH::ConstraintSettings *in) { assert(in); return reinterpret_cast<JOLT_ConstraintSettings *>(in); }

FN(toJph)(const JOLT_TwoBodyConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::TwoBodyConstraintSettings);
    return reinterpret_cast<const JPH::TwoBodyConstraintSettings *>(in);
}
FN(toJph)(JOLT_TwoBodyConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::TwoBodyConstraintSettings);
    return reinterpret_cast<JPH::TwoBodyConstraintSettings *>(in);
}
FN(toJpc)(const JPH::TwoBodyConstraintSettings *in) { assert(in); return reinterpret_cast<const JOLT_TwoBodyConstraintSettings *>(in); }
FN(toJpc)(JPH::TwoBodyConstraintSettings *in) { assert(in); return reinterpret_cast<JOLT_TwoBodyConstraintSettings *>(in); }

FN(toJph)(const JOLT_FixedConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::FixedConstraintSettings);
    return reinterpret_cast<const JPH::FixedConstraintSettings *>(in);
}
FN(toJph)(JOLT_FixedConstraintSettings *in) {
    ENSURE_TYPE(in, JPH::FixedConstraintSettings);
    return reinterpret_cast<JPH::FixedConstraintSettings *>(in);
}
FN(toJpc)(JPH::FixedConstraintSettings *in) { assert(in); return reinterpret_cast<JOLT_FixedConstraintSettings *>(in); }

FN(toJph)(const JOLT_CollisionGroup *in) { assert(in); return reinterpret_cast<const JPH::CollisionGroup *>(in); }
FN(toJpc)(const JPH::CollisionGroup *in) { assert(in); return reinterpret_cast<const JOLT_CollisionGroup *>(in); }
FN(toJpc)(JPH::CollisionGroup *in) { assert(in); return reinterpret_cast<JOLT_CollisionGroup *>(in); }

FN(toJph)(const JOLT_SubShapeID *in) { assert(in); return reinterpret_cast<const JPH::SubShapeID *>(in); }

FN(toJph)(const JOLT_BodyLockInterface *in) {
    assert(in); return reinterpret_cast<const JPH::BodyLockInterface *>(in);
}
FN(toJpc)(const JPH::BodyLockInterface *in) {
    assert(in); return reinterpret_cast<const JOLT_BodyLockInterface *>(in);
}

FN(toJpc)(const JPH::NarrowPhaseQuery *in) {
    assert(in); return reinterpret_cast<const JOLT_NarrowPhaseQuery *>(in);
}

FN(toJph)(const JOLT_PhysicsSystem *in) { assert(in); return reinterpret_cast<const JPH::PhysicsSystem *>(in); }
FN(toJph)(JOLT_PhysicsSystem *in) { assert(in); return reinterpret_cast<JPH::PhysicsSystem *>(in); }
FN(toJpc)(JPH::PhysicsSystem *in) { assert(in); return reinterpret_cast<JOLT_PhysicsSystem *>(in); }

FN(toJpc)(const JPH::Shape *in) { assert(in); return reinterpret_cast<const JOLT_Shape *>(in); }
FN(toJph)(const JOLT_Shape *in) { assert(in); return reinterpret_cast<const JPH::Shape *>(in); }
FN(toJpc)(JPH::Shape *in) { assert(in); return reinterpret_cast<JOLT_Shape *>(in); }
FN(toJph)(JOLT_Shape *in) { assert(in); return reinterpret_cast<JPH::Shape *>(in); }

FN(toJpc)(const JPH::Constraint *in) { assert(in); return reinterpret_cast<const JOLT_Constraint *>(in); }
FN(toJph)(const JOLT_Constraint *in) { assert(in); return reinterpret_cast<const JPH::Constraint *>(in); }
FN(toJpc)(JPH::Constraint *in) { assert(in); return reinterpret_cast<JOLT_Constraint *>(in); }
FN(toJph)(JOLT_Constraint *in) { assert(in); return reinterpret_cast<JPH::Constraint *>(in); }

FN(toJpc)(const JPH::BodyInterface *in) { assert(in); return reinterpret_cast<const JOLT_BodyInterface *>(in); }
FN(toJph)(const JOLT_BodyInterface *in) { assert(in); return reinterpret_cast<const JPH::BodyInterface *>(in); }
FN(toJpc)(JPH::BodyInterface *in) { assert(in); return reinterpret_cast<JOLT_BodyInterface *>(in); }
FN(toJph)(JOLT_BodyInterface *in) { assert(in); return reinterpret_cast<JPH::BodyInterface *>(in); }

FN(toJpc)(const JPH::TransformedShape *in) { assert(in); return reinterpret_cast<const JOLT_TransformedShape *>(in); }

FN(toJph)(const JOLT_MassProperties *in) { assert(in); return reinterpret_cast<const JPH::MassProperties *>(in); }

FN(toJph)(JOLT_BodyLockRead *in) { assert(in); return reinterpret_cast<const JPH::BodyLockRead *>(in); }
FN(toJph)(JOLT_BodyLockWrite *in) { assert(in); return reinterpret_cast<const JPH::BodyLockWrite *>(in); }

FN(toJpc)(const JPH::BodyCreationSettings *in) {
    assert(in); return reinterpret_cast<const JOLT_BodyCreationSettings *>(in);
}
FN(toJph)(const JOLT_BodyCreationSettings *in) {
    assert(in); return reinterpret_cast<const JPH::BodyCreationSettings *>(in);
}

FN(toJpc)(const JPH::MotionProperties *in) { assert(in); return reinterpret_cast<const JOLT_MotionProperties *>(in); }
FN(toJph)(const JOLT_MotionProperties *in) { assert(in); return reinterpret_cast<const JPH::MotionProperties *>(in); }
FN(toJpc)(JPH::MotionProperties *in) { assert(in); return reinterpret_cast<JOLT_MotionProperties *>(in); }
FN(toJph)(JOLT_MotionProperties *in) { assert(in); return reinterpret_cast<JPH::MotionProperties *>(in); }

FN(toJpc)(const JPH::SubShapeIDPair *in) {
    assert(in); return reinterpret_cast<const JOLT_SubShapeIDPair *>(in);
}

FN(toJpc)(const JPH::ContactManifold *in) {
    assert(in); return reinterpret_cast<const JOLT_ContactManifold *>(in);
}

FN(toJpc)(const JPH::CollideShapeResult *in) {
    assert(in); return reinterpret_cast<const JOLT_CollideShapeResult *>(in);
}

FN(toJpc)(JPH::ContactSettings *in) {
    assert(in); return reinterpret_cast<JOLT_ContactSettings *>(in);
}

FN(toJpc)(JPH::BroadPhaseLayer in) { return static_cast<JOLT_BroadPhaseLayer>(in); }
FN(toJpc)(JPH::ObjectLayer in) { return static_cast<JOLT_ObjectLayer>(in); }
FN(toJpc)(JPH::EShapeType in) { return static_cast<JOLT_ShapeType>(in); }
FN(toJpc)(JPH::EShapeSubType in) { return static_cast<JOLT_ShapeSubType>(in); }
FN(toJpc)(JPH::EConstraintType in) { return static_cast<JOLT_ConstraintType>(in); }
FN(toJpc)(JPH::EConstraintSubType in) { return static_cast<JOLT_ConstraintSubType>(in); }
FN(toJpc)(JPH::EConstraintSpace in) { return static_cast<JOLT_ConstraintSpace>(in); }
FN(toJpc)(JPH::EMotionType in) { return static_cast<JOLT_MotionType>(in); }
FN(toJpc)(JPH::EActivation in) { return static_cast<JOLT_Activation>(in); }
FN(toJpc)(JPH::EMotionQuality in) { return static_cast<JOLT_MotionQuality>(in); }
FN(toJpc)(JPH::CharacterBase::EGroundState in) { return static_cast<JOLT_CharacterGroundState>(in); }

FN(toJph)(JOLT_ConstraintSpace in) { return static_cast<JPH::EConstraintSpace>(in); }

FN(toJph)(const JOLT_Character *in) { assert(in); return reinterpret_cast<const JPH::Character *>(in); }
FN(toJph)(JOLT_Character *in) { assert(in); return reinterpret_cast<JPH::Character *>(in); }
FN(toJpc)(const JPH::Character *in) { assert(in); return reinterpret_cast<const JOLT_Character *>(in); }
FN(toJpc)(JPH::Character *in) { assert(in); return reinterpret_cast<JOLT_Character *>(in); }

FN(toJph)(const JOLT_CharacterSettings *in) { assert(in); return reinterpret_cast<const JPH::CharacterSettings *>(in); }
FN(toJph)(JOLT_CharacterSettings *in) { assert(in); return reinterpret_cast<JPH::CharacterSettings *>(in); }
FN(toJpc)(const JPH::CharacterSettings *in) { assert(in); return reinterpret_cast<const JOLT_CharacterSettings *>(in); }
FN(toJpc)(JPH::CharacterSettings *in) { assert(in); return reinterpret_cast<JOLT_CharacterSettings *>(in); }

FN(toJph)(const JOLT_CharacterVirtual *in) { assert(in); return reinterpret_cast<const JPH::CharacterVirtual *>(in); }
FN(toJph)(JOLT_CharacterVirtual *in) { assert(in); return reinterpret_cast<JPH::CharacterVirtual *>(in); }
FN(toJpc)(const JPH::CharacterVirtual *in) { assert(in); return reinterpret_cast<const JOLT_CharacterVirtual *>(in); }
FN(toJpc)(JPH::CharacterVirtual *in) { assert(in); return reinterpret_cast<JOLT_CharacterVirtual *>(in); }

FN(toJph)(const JOLT_CharacterVirtualSettings *in) { assert(in); return reinterpret_cast<const JPH::CharacterVirtualSettings *>(in); }
FN(toJph)(JOLT_CharacterVirtualSettings *in) { assert(in); return reinterpret_cast<JPH::CharacterVirtualSettings *>(in); }
FN(toJpc)(const JPH::CharacterVirtualSettings *in) { assert(in); return reinterpret_cast<const JOLT_CharacterVirtualSettings *>(in); }
FN(toJpc)(JPH::CharacterVirtualSettings *in) { assert(in); return reinterpret_cast<JOLT_CharacterVirtualSettings *>(in); }


//--------------------------------------------------------------------------------------------------
//
// JOLT_TempAllocator
//
//--------------------------------------------------------------------------------------------------
JOLT_TempAllocator* JOLT_TempAllocator_Create(uint32_t in_size)
{
    auto impl = new JPH::TempAllocatorImpl(in_size);
    return reinterpret_cast<JOLT_TempAllocator*>(impl);
}
//--------------------------------------------------------------------------------------------------
void JOLT_TempAllocator_Destroy(JOLT_TempAllocator*in_allocator)
{
    assert(in_allocator != nullptr);
    delete reinterpret_cast<JPH::TempAllocator *>(in_allocator);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_JobSystem
//
//--------------------------------------------------------------------------------------------------
JOLT_JobSystem * JOLT_JobSystem_Create(uint32_t in_max_jobs, uint32_t in_max_barriers, int in_num_threads)
{
    auto job_system = new JPH::JobSystemThreadPool(in_max_jobs, in_max_barriers, in_num_threads);
    return reinterpret_cast<JOLT_JobSystem *>(job_system);
}
//--------------------------------------------------------------------------------------------------
void JOLT_JobSystem_Destroy(JOLT_JobSystem *in_job_system)
{
    assert(in_job_system != nullptr);
    delete reinterpret_cast<JPH::JobSystemThreadPool *>(in_job_system);
}

// Callback for traces, connect this to your own trace function if you have one
static void TraceImpl(const char *inFMT, ...)
{
	// Format the message
	va_list list;
	va_start(list, inFMT);
	char buffer[1024];
	vsnprintf(buffer, sizeof(buffer), inFMT, list);
	va_end(list);

	// Print to the TTY
	cout << buffer << endl;
}

#ifdef JPH_ENABLE_ASSERTS

// Callback for asserts, connect this to your own assert handler if you have one
static bool AssertFailedImpl(const char *inExpression, const char *inMessage, const char *inFile, uint inLine)
{
	// Print to the TTY
	cout << inFile << ":" << inLine << ": (" << inExpression << ") " << (inMessage != nullptr? inMessage : "") << endl;

	// Breakpoint
	return true;
};

#endif // JPH_ENABLE_ASSERTS

// Layer that objects can be in, determines which other objects it can collide with
// Typically you at least want to have 1 layer for moving bodies and 1 layer for static bodies, but you can have more
// layers if you want. E.g. you could have a layer for high detail collision (which is not used by the physics simulation
// but only if you do collision testing).
namespace Layers
{
	static constexpr ObjectLayer NON_MOVING = 0;
	static constexpr ObjectLayer MOVING = 1;
	static constexpr ObjectLayer NUM_LAYERS = 2;
};

/// Class that determines if two object layers can collide
class ObjectLayerPairFilterImpl : public ObjectLayerPairFilter
{
public:
	virtual bool ShouldCollide(ObjectLayer inObject1, ObjectLayer inObject2) const override
	{
		/*
		switch (inObject1)
		{
		case Layers::NON_MOVING:
			return inObject2 == Layers::MOVING; // Non moving only collides with moving
		case Layers::MOVING:
			return true; // Moving collides with everything
		default:
			JPH_ASSERT(false);
			return false;
		}
		*/
		bool result = false;
		if (fp != nullptr){
			result = this->fp(inObject1,inObject2);
		}
		return result;
	}

	bool (*fp)(JOLT_ObjectLayer inLayer1,JOLT_ObjectLayer inLayer2);
	void SetFunctionPointer(bool(*externalFunction)(JOLT_ObjectLayer inLayer1,JOLT_ObjectLayer inLayer2)) {
        // Cast the external function pointer to the member function pointer type
        fp = externalFunction;
    }
};

// Each broadphase layer results in a separate bounding volume tree in the broad phase. You at least want to have
// a layer for non-moving and moving objects to avoid having to update a tree full of static objects every frame.
// You can have a 1-on-1 mapping between object layers and broadphase layers (like in this case) but if you have
// many object layers you'll be creating many broad phase trees, which is not efficient. If you want to fine tune
// your broadphase layers define JPH_TRACK_BROADPHASE_STATS and look at the stats reported on the TTY.
namespace BroadPhaseLayers
{
	static constexpr BroadPhaseLayer NON_MOVING(0);
	static constexpr BroadPhaseLayer MOVING(1);
	static constexpr uint NUM_LAYERS(2);
};



// BroadPhaseLayerInterface implementation
// This defines a mapping between object and broadphase layers.
class BPLayerInterfaceImpl final : public BroadPhaseLayerInterface
{
public:
	BPLayerInterfaceImpl()
	{
		// Create a mapping table from object to broad phase layer
		mObjectToBroadPhase[Layers::NON_MOVING] = BroadPhaseLayers::NON_MOVING;
		mObjectToBroadPhase[Layers::MOVING] = BroadPhaseLayers::MOVING;
	}

	virtual uint GetNumBroadPhaseLayers() const override
	{
		uint result = 0;
		if (fp != nullptr){
			result = (this->fp)();
		}
		//return BroadPhaseLayers::NUM_LAYERS;
		return result;
	}

	virtual BroadPhaseLayer GetBroadPhaseLayer(ObjectLayer inLayer) const override
	{
		JPH_ASSERT(inLayer < Layers::NUM_LAYERS);
		//return mObjectToBroadPhase[inLayer];
		JOLT_BroadPhaseLayer result = {};
		if (getBroadPhaseLayerFP != nullptr){
			result = this->getBroadPhaseLayerFP(inLayer);
		}
		return (BroadPhaseLayer)result;
	}

#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
	virtual const char *			GetBroadPhaseLayerName(BroadPhaseLayer inLayer) const override
	{
		switch ((BroadPhaseLayer::Type)inLayer)
		{
		case (BroadPhaseLayer::Type)BroadPhaseLayers::NON_MOVING:	return "NON_MOVING";
		case (BroadPhaseLayer::Type)BroadPhaseLayers::MOVING:		return "MOVING";
		default:													JPH_ASSERT(false); return "INVALID";
		}
	}
#endif // JPH_EXTERNAL_PROFILE || JPH_PROFILE_ENABLED

	uint32_t (*fp)();
	void SetFunctionPointer(uint32_t(*externalFunction)()) {
        // Cast the external function pointer to the member function pointer type
        fp = externalFunction;
    }

	JOLT_BroadPhaseLayer (*getBroadPhaseLayerFP)(JOLT_ObjectLayer inLayer);
	void SetGetBroadPhaseLayerFunctionPtr(JOLT_BroadPhaseLayer(*externalFunction)(JOLT_ObjectLayer inLayer)) {
        // Cast the external function pointer to the member function pointer type
        getBroadPhaseLayerFP = externalFunction;
    }
private:
	BroadPhaseLayer					mObjectToBroadPhase[Layers::NUM_LAYERS];
};

/// Class that determines if an object layer can collide with a broadphase layer
class ObjectVsBroadPhaseLayerFilterImpl : public ObjectVsBroadPhaseLayerFilter
{
public:
	virtual bool ShouldCollide(ObjectLayer inLayer1, BroadPhaseLayer inLayer2) const override
	{
		/*
		switch (inLayer1)
		{
		case Layers::NON_MOVING:
			return inLayer2 == BroadPhaseLayers::MOVING;
		case Layers::MOVING:
			return true;
		default:
			JPH_ASSERT(false);
			return false;
		}
		*/
		bool result = false;
		if (fp != nullptr){
			result = this->fp(inLayer1,(JOLT_BroadPhaseLayer)(inLayer2));
		}
		return result;
	}

	bool (*fp)(JOLT_ObjectLayer inLayer1,JOLT_BroadPhaseLayer inLayer2);
	void SetFunctionPointer(bool(*externalFunction)(JOLT_ObjectLayer inLayer1,JOLT_BroadPhaseLayer inLayer2)) {
        // Cast the external function pointer to the member function pointer type
        fp = externalFunction;
    }
	
};

class InternalContactListener : public ContactListener
{
public:
	// See: ContactListener
	virtual ValidateResult	OnContactValidate(const Body &inBody1, const Body &inBody2, RVec3Arg inBaseOffset, const CollideShapeResult &inCollisionResult) override
	{
		// Allows you to ignore a contact before it is created (using layers to not make objects collide is cheaper!)
		return static_cast<ValidateResult>(this->OnContactValidateFP((JOLT_Body*)&inBody1,(JOLT_Body*)&inBody2,(Vec3)inBaseOffset,(JOLT_CollideShapeResult*)(&inCollisionResult)));
	}

	virtual void			OnContactAdded(const Body &inBody1, const Body &inBody2, const ContactManifold &inManifold, ContactSettings &ioSettings) override
	{
		this->OnContactAddedFP((JOLT_Body*)&inBody1,(JOLT_Body*)&inBody2,(JOLT_ContactManifold*)&inManifold,(JOLT_ContactSettings*)&ioSettings);
	}

	virtual void			OnContactPersisted(const Body &inBody1, const Body &inBody2, const ContactManifold &inManifold, ContactSettings &ioSettings) override
	{
		this->OnContactPersistedFP((JOLT_Body*)&inBody1,(JOLT_Body*)&inBody2,(JOLT_ContactManifold*)&inManifold,(JOLT_ContactSettings*)&ioSettings);
	}

	virtual void			OnContactRemoved(const SubShapeIDPair &inSubShapePair) override
	{
		this->OnContactRemovedFP((JOLT_SubShapeIDPair*)&inSubShapePair);
	}
	
	void (*OnContactAddedFP)(const JOLT_Body *inBody1,const JOLT_Body *inBody2,const JOLT_ContactManifold *inManifold,JOLT_ContactSettings *ioSettings);
	void SetOnContactAddedProc(void (*OnContactAddedFPParam)(const JOLT_Body *inBody1,const JOLT_Body *inBody2,const JOLT_ContactManifold *inManifold,JOLT_ContactSettings *ioSettings)){
        OnContactAddedFP = OnContactAddedFPParam;
    }

	JOLT_ValidateResult (*OnContactValidateFP)(const JOLT_Body *inBody1,const JOLT_Body *inBody2,RVec3Arg inBaseOffset,JOLT_CollideShapeResult *inCollisionResult);
	void SetOnContactValidateProc(JOLT_ValidateResult(*OnContactValidateParam)(const JOLT_Body *inBody1,const JOLT_Body *inBody2,RVec3Arg inBaseOffset,JOLT_CollideShapeResult *inCollisionResult)){
        OnContactValidateFP = OnContactValidateParam;
    }

	void (*OnContactPersistedFP)(JOLT_Body *inBody1,JOLT_Body *inBody2,JOLT_ContactManifold* inManifold,JOLT_ContactSettings *ioSettings);
	void SetOnContactValidateProc(void(*OnContactPersistedParam)(JOLT_Body *inBody1,JOLT_Body *inBody2,JOLT_ContactManifold* inManifold,JOLT_ContactSettings *ioSettings)){
        OnContactPersistedFP = OnContactPersistedParam;
    }

	void (*OnContactRemovedFP)(JOLT_SubShapeIDPair* inSubShapePair);
	void SetOnContactRemovedProc(void(*OnContactRemovedParam)(JOLT_SubShapeIDPair* inSubShapePair)){
        OnContactRemovedFP = OnContactRemovedParam;
    }
};

// An example activation listener
class MyBodyActivationListener : public BodyActivationListener
{
public:
	virtual void		OnBodyActivated(const BodyID &inBodyID, uint64 inBodyUserData) override
	{
		cout << "A body got activated" << endl;
	}

	virtual void		OnBodyDeactivated(const BodyID &inBodyID, uint64 inBodyUserData) override
	{
		cout << "A body went to sleep" << endl;
	}
};

void JOLT_RegisterDefaultAllocator(){
	RegisterDefaultAllocator();
}

void
JOLT_RegisterCustomAllocator(JOLT_AllocateFunction in_alloc,
                            JOLT_FreeFunction in_free,
                            JOLT_AlignedAllocateFunction in_aligned_alloc,
                            JOLT_AlignedFreeFunction in_aligned_free)
{
#ifndef JPH_DISABLE_CUSTOM_ALLOCATOR
    JPH::Allocate = in_alloc;
    JPH::Free = in_free;
    JPH::AlignedAllocate = in_aligned_alloc;
    JPH::AlignedFree = in_aligned_free;
#endif
}
void JOLT_RegisterTypes(){
	// Register all Jolt physics types
	//If you have missed compile flags between the compiled lib of jolt and the bindings lib it will fail
	Factory::sInstance = new Factory();
	RegisterTypes();
}

//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyInterface
//
//--------------------------------------------------------------------------------------------------

/*
FN(toJpc)(const JPH::BodyInterface *in) { assert(in); return reinterpret_cast<const JOLT_BodyInterface *>(in); }
FN(toJph)(const JOLT_BodyInterface *in) { assert(in); return reinterpret_cast<const JPH::BodyInterface *>(in); }
FN(toJpc)(JPH::BodyInterface *in) { assert(in); return reinterpret_cast<JOLT_BodyInterface *>(in); }
FN(toJph)(JOLT_BodyInterface *in) { assert(in); return reinterpret_cast<JPH::BodyInterface *>(in); }
*/

static inline JPH::Vec3 loadVec3(const float in[3]) {
    assert(in != nullptr);
    return JPH::Vec3(*reinterpret_cast<const JPH::Float3 *>(in));
}

static inline JPH::Vec4 loadVec4(const float in[4]) {
    assert(in != nullptr);
    return JPH::Vec4::sLoadFloat4(reinterpret_cast<const JPH::Float4 *>(in));
}

static inline JPH::Mat44 loadMat44(const float in[16]) {
    assert(in != nullptr);
    return JPH::Mat44::sLoadFloat4x4(reinterpret_cast<const JPH::Float4 *>(in));
}

static inline JPH::RVec3 loadRVec3(const JOLT_Real in[3]) {
    assert(in != nullptr);
#if JOLT_DOUBLE_PRECISION == 0
    return JPH::Vec3(*reinterpret_cast<const JPH::Float3 *>(in));
#else
    return JPH::DVec3(in[0], in[1], in[2]);
#endif
}

static inline void storeRVec3(JOLT_Real out[3], JPH::RVec3Arg in) {
    assert(out != nullptr);
#if JOLT_DOUBLE_PRECISION == 0
    in.StoreFloat3(reinterpret_cast<JPH::Float3 *>(out));
#else
    in.StoreDouble3(reinterpret_cast<JPH::Double3 *>(out));
#endif
}

static inline void storeVec3(float out[3], JPH::Vec3Arg in) {
    assert(out != nullptr);
    in.StoreFloat3(reinterpret_cast<JPH::Float3 *>(out));
}

static inline void storeVec4(float out[4], JPH::Vec4Arg in) {
    assert(out != nullptr);
    in.StoreFloat4(reinterpret_cast<JPH::Float4 *>(out));
}

static inline void storeMat44(float out[16], JPH::Mat44Arg in) {
    assert(out != nullptr);
    in.StoreFloat4x4(reinterpret_cast<JPH::Float4 *>(out));
}

JOLT_Body* JOLT_BodyInterface_CreateBody(JOLT_BodyInterface *in_iface,JOLT_BodyCreationSettings *in_settings){
	auto iface = reinterpret_cast<JPH::BodyInterface*>(in_iface);
	auto inset = *reinterpret_cast<JPH::BodyCreationSettings*>(in_settings);
	auto result_pre = iface->CreateBody(inset);
	auto result_post = reinterpret_cast<JOLT_Body*>(result_pre);
	return result_post;
    //return toJpc(toJph(in_iface)->CreateBody(*toJph(in_settings)));
}
/*

//--------------------------------------------------------------------------------------------------
JOLT_Body* JOLT_BodyInterface_CreateBodyWithID(JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_BodyCreationSettings *in_settings)
{
	auto iface = (JPH::BodyInterface*)(in_iface);
	auto inbid = (JPH::BodyID)(in_body_id);
	auto inset = *reinterpret_cast<const JPH::BodyCreationSettings*>(in_settings);

	auto result_pre = iface->CreateBodyWithID(inbid,inset); 
	auto result_post = (JOLT_Body*)(result_pre);
	return result_post;
    //return toJpc(toJph(in_iface)->CreateBodyWithID(toJph(in_body_id), *toJph(in_settings)));
}
//--------------------------------------------------------------------------------------------------
void JOLT_BodyInterface_AddBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_Activation in_mode)
{
    toJph(in_iface)->AddBody(toJph(in_body_id), static_cast<JPH::EActivation>(in_mode));
}


//--------------------------------------------------------------------------------------------------
void JOLT_BodyInterface_DestroyBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    toJph(in_iface)->DestroyBody(toJph(in_body_id));
}

 JOLT_BodyID
JOLT_BodyInterface_CreateAndAddBody(JOLT_BodyInterface *in_iface,
                                   const JOLT_BodyCreationSettings *in_settings,
                                   JOLT_Activation in_mode)
{
    return toJpc(toJph(in_iface)->CreateAndAddBody(*toJph(in_settings),
        static_cast<JPH::EActivation>(in_mode)));
}

 void JOLT_BodyInterface_SetLinearVelocity(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    float in_velocity[3])
{
    toJph(in_iface)->SetLinearVelocity(toJph(in_body_id), loadVec3(in_velocity));
}

 void JOLT_BodyInterface_GetCenterOfMassPosition(const JOLT_BodyInterface *in_iface,
                                          JOLT_BodyID in_body_id,
                                          JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_iface)->GetCenterOfMassPosition(toJph(in_body_id)));
}

 bool JOLT_BodyInterface_IsActive(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    return toJph(in_iface)->IsActive(toJph(in_body_id));
}
 void JOLT_BodyInterface_GetLinearVelocity(const JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_iface)->GetLinearVelocity(toJph(in_body_id)));
}

//
//
//--------------------------------------------------------------------------------------------------
//
// JOLT_Body
//
//--------------------------------------------------------------------------------------------------
 JOLT_BodyID
JOLT_Body_GetID(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetID().GetIndexAndSequenceNumber();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsActive(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsActive();
}
*/

//--------------------------------------------------------------------------------------------------
void JOLT_BodyCreationSettings_SetDefault(JOLT_BodyCreationSettings *out_settings)
{
    assert(out_settings != nullptr);
    const JPH::BodyCreationSettings settings;
    *out_settings = *toJpc(&settings);
}
//--------------------------------------------------------------------------------------------------
void JOLT_BodyCreationSettings_Set(JOLT_BodyCreationSettings *out_settings,
                             const JOLT_Shape *in_shape,
                             const JOLT_Real in_position[3],
                             const float in_rotation[4],
                             JOLT_MotionType in_motion_type,
                             JOLT_ObjectLayer in_layer)
{
    assert(out_settings != nullptr && in_shape != nullptr && in_position != nullptr && in_rotation != nullptr);

    JOLT_BodyCreationSettings settings;
    JOLT_BodyCreationSettings_SetDefault(&settings);

    settings.position[0] = in_position[0];
    settings.position[1] = in_position[1];
    settings.position[2] = in_position[2];
    settings.rotation[0] = in_rotation[0];
    settings.rotation[1] = in_rotation[1];
    settings.rotation[2] = in_rotation[2];
    settings.rotation[3] = in_rotation[3];
    settings.object_layer = in_layer;
    settings.motion_type = in_motion_type;
    settings.shapePtr = in_shape;
    *out_settings = settings;
}

//--------------------------------------------------------------------------------------------------
//
// JOLT_BoxShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
/*
JOLT_BoxShapeSettings *JOLT_BoxShapeSettings_Create(const float in_half_extent[3])
{
    auto settings = new JPH::BoxShapeSettings(loadVec3(in_half_extent));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
void JOLT_BoxShapeSettings_GetHalfExtent(const JOLT_BoxShapeSettings *in_settings, float out_half_extent[3])
{
    storeVec3(out_half_extent, toJph(in_settings)->mHalfExtent);
}
//--------------------------------------------------------------------------------------------------
void JOLT_BoxShapeSettings_SetHalfExtent(JOLT_BoxShapeSettings *in_settings, const float in_half_extent[3])
{
    toJph(in_settings)->mHalfExtent = loadVec3(in_half_extent);
}
//--------------------------------------------------------------------------------------------------
float JOLT_BoxShapeSettings_GetConvexRadius(const JOLT_BoxShapeSettings *in_settings)
{
    return toJph(in_settings)->mConvexRadius;
}
//--------------------------------------------------------------------------------------------------
void JOLT_BoxShapeSettings_SetConvexRadius(JOLT_BoxShapeSettings *in_settings, float in_convex_radius)
{
    toJph(in_settings)->mConvexRadius = in_convex_radius;
}

//--------------------------------------------------------------------------------------------------
//
// JOLT_SphereShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_SphereShapeSettings *
JOLT_SphereShapeSettings_Create(float in_radius)
{
    auto settings = new JPH::SphereShapeSettings(in_radius);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_SphereShapeSettings_GetRadius(const JOLT_SphereShapeSettings *in_settings)
{
    return toJph(in_settings)->mRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_SphereShapeSettings_SetRadius(JOLT_SphereShapeSettings *in_settings, float in_radius)
{
    toJph(in_settings)->mRadius = in_radius;
}
*/

//--------------------------------------------------------------------------------------------------
//
// JOLT_ShapeSettings
//
//--------------------------------------------------------------------------------------------------
/*
void JOLT_ShapeSettings_AddRef(JOLT_ShapeSettings *in_settings)
{
    toJph(in_settings)->AddRef();
}
//--------------------------------------------------------------------------------------------------
void JOLT_ShapeSettings_Release(JOLT_ShapeSettings *in_settings)
{
    toJph(in_settings)->Release();
}
//--------------------------------------------------------------------------------------------------
uint32_t JOLT_ShapeSettings_GetRefCount(const JOLT_ShapeSettings *in_settings)
{
    return toJph(in_settings)->GetRefCount();
}

 void JOLT_Shape_GetCenterOfMass(const JOLT_Shape *in_shape, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_shape)->GetCenterOfMass());
}

//--------------------------------------------------------------------------------------------------
JOLT_Shape * JOLT_ShapeSettings_CreateShape(const JOLT_ShapeSettings *in_settings)
{
    const JPH::Result result = toJph(in_settings)->Create();
    if (result.HasError()) return nullptr;
    JPH::Shape *shape = const_cast<JPH::Shape *>(result.Get().GetPtr());
    shape->AddRef();
    return toJpc(shape);
}
//--------------------------------------------------------------------------------------------------
uint64_t JOLT_ShapeSettings_GetUserData(const JOLT_ShapeSettings *in_settings)
{
    return toJph(in_settings)->mUserData;
}
//--------------------------------------------------------------------------------------------------
void JOLT_ShapeSettings_SetUserData(JOLT_ShapeSettings *in_settings, uint64_t in_user_data)
{
    toJph(in_settings)->mUserData = in_user_data;
}
*/
//---

JOLT_BodyInterface* JOLT_GetBodyInterface(JOLT_PhysicsSystem* ps){
	//(ps != nullptr)
	if (ps == nullptr)return nullptr;
	return (JOLT_BodyInterface*)&(reinterpret_cast<JPH::PhysicsSystem*>(ps))->GetBodyInterface();
}

struct PhysicsSystemData
{
    uint64_t safety_token = 0xC0DEC0DEC0DEC0DE;
    ContactListener *contact_listener = nullptr;
};


BPLayerInterfaceImpl broad_phase_layer_interface;
ObjectVsBroadPhaseLayerFilterImpl object_vs_broadphase_layer_filter;
ObjectLayerPairFilterImpl object_layer_pair_filter;

JOLT_PhysicsSystem *
JOLT_PhysicsSystem_Create(uint32_t in_max_bodies,
                         uint32_t in_num_body_mutexes,
                         uint32_t in_max_body_pairs,
                         uint32_t in_max_contact_constraints,
                         JOLT_BroadPhaseLayerInterfaceVTable in_broad_phase_layer_interface,
                         //const void *in_object_vs_broad_phase_layer_filter,
                         JOLT_ObjectVsBroadPhaseLayerFilterVTable in_object_vs_broad_phase_layer_filter,
                         JOLT_ObjectLayerPairFilterVTable in_object_layer_pair_filter)
{
    //assert(in_broad_phase_layer_interface != nullptr);
    //assert(in_object_vs_broad_phase_layer_filter != nullptr);
    //assert(in_object_layer_pair_filter != nullptr);

    auto physics_system =
        static_cast<JPH::PhysicsSystem *>(
            JPH::Allocate(sizeof(JPH::PhysicsSystem) + sizeof(PhysicsSystemData)));
    ::new (physics_system) JPH::PhysicsSystem();

	/*
    PhysicsSystemData* data =
        ::new (reinterpret_cast<uint8_t *>(physics_system) + sizeof(JPH::PhysicsSystem)) PhysicsSystemData();
    assert(data->safety_token == 0xC0DEC0DEC0DEC0DE);
	*/

	//JPH::BroadPhaseLayerInterface* test = reinterpret_cast<JPH::BroadPhaseLayerInterface *>(&in_broad_phase_layer_interface);

	// Create mapping table from object layer to broadphase layer
	// Note: As this is an interface, PhysicsSystem will take a reference to this so this instance needs to stay alive!
	broad_phase_layer_interface.SetFunctionPointer(in_broad_phase_layer_interface.GetNumBroadPhaseLayers);
	broad_phase_layer_interface.SetGetBroadPhaseLayerFunctionPtr(in_broad_phase_layer_interface.GetBroadPhaseLayer);

	object_vs_broadphase_layer_filter.SetFunctionPointer(in_object_vs_broad_phase_layer_filter.ShouldCollide);

	object_layer_pair_filter.SetFunctionPointer(in_object_layer_pair_filter.ShouldCollide);

    physics_system->Init(
        in_max_bodies,
        in_num_body_mutexes,
        in_max_body_pairs,
        in_max_contact_constraints,
		broad_phase_layer_interface,
		object_vs_broadphase_layer_filter,
        //*static_cast<const JPH::ObjectVsBroadPhaseLayerFilter *>(in_object_vs_broad_phase_layer_filter),
        //*static_cast<const JPH::ObjectLayerPairFilter *>(in_object_layer_pair_filter));
		object_layer_pair_filter);

    return reinterpret_cast<JOLT_PhysicsSystem *>(physics_system);
}

/*
 void JOLT_PhysicsSystem_OptimizeBroadPhase(JOLT_PhysicsSystem *in_physics_system)
{
    toJph(in_physics_system)->OptimizeBroadPhase();
}
*/

//--------------------------------------------------------------------------------------------------
 JOLT_PhysicsUpdateError JOLT_PhysicsSystem_Update(JOLT_PhysicsSystem *in_physics_system,
                         float in_delta_time,
                         int in_collision_steps,
                         int in_integration_sub_steps,
                         JOLT_TempAllocator *in_temp_allocator,
                         JOLT_JobSystem *in_job_system)
{
    assert(in_temp_allocator != nullptr && in_job_system != nullptr);
    JOLT_PhysicsUpdateError error = (JOLT_PhysicsUpdateError)toJph(in_physics_system)->Update(
        in_delta_time,
        in_collision_steps,
        //in_integration_sub_steps,
        reinterpret_cast<JPH::TempAllocator *>(in_temp_allocator),
        reinterpret_cast<JPH::JobSystem *>(in_job_system));
    return error;
}

//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_SetBodyActivationListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener)
{
    toJph(in_physics_system)->SetBodyActivationListener(static_cast<JPH::BodyActivationListener *>(in_listener));
}
//--------------------------------------------------------------------------------------------------
 void *
JOLT_PhysicsSystem_GetBodyActivationListener(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJph(in_physics_system)->GetBodyActivationListener();
}

InternalContactListener cl;
//
//--------------------------------------------------------------------------------------------------
void JOLT_SetContactListener(JOLT_PhysicsSystem *in_physics_system, JOLT_ContactListenerVTable *in_listener)
{
    if (in_listener == nullptr)
    {
        toJph(in_physics_system)->SetContactListener(nullptr);
        return;
    }

	/*
    auto data = reinterpret_cast<PhysicsSystemData *>(
        reinterpret_cast<uint8_t *>(in_physics_system) + sizeof(JPH::PhysicsSystem));
    assert(data->safety_token == 0xC0DEC0DEC0DEC0DE);

    if (data->contact_listener == nullptr)
    {
        data->contact_listener = static_cast<ContactListener *>(JPH::Allocate(sizeof(ContactListener)));
        ::new (data->contact_listener) ContactListener();
    }
	*/
	/*
	void (*OnContactAddedFP)(const Body &inBody1,const Body &inBody2,const ContactManifold &inManifold,ContactSettings &ioSettings);
	void SetOnContactAddedProc(void (*OnContactAddedFPParam)(const Body &inBody1,const Body &inBody2,const ContactManifold &inManifold,ContactSettings &ioSettings)){
        // Cast the external function pointer to the member function pointer type
        OnContactAddedFP = OnContactAddedFPParam;
    }
	*/

	cl.SetOnContactAddedProc(in_listener->OnContactAdded);

    //toJph(in_physics_system)->SetContactListener(data->contact_listener);

    //data->contact_listener->c_listener = static_cast<ContactListener::CListener *>(in_listener);
}

//TODO(Ray):Watch out too tired right now but we need to double check here.
 void *
JOLT_PhysicsSystem_GetContactListener(const JOLT_PhysicsSystem *in_physics_system)
{
    auto listener = static_cast<ContactListener *>(toJph(in_physics_system)->GetContactListener());
    if (listener == nullptr)
        return nullptr;
    return listener;
}

//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_PhysicsSystem_GetNumBodies(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJph(in_physics_system)->GetNumBodies();
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_PhysicsSystem_GetNumActiveBodies(const JOLT_PhysicsSystem *in_physics_system,JOLT_BodyType type)
{
    return toJph(in_physics_system)->GetNumActiveBodies((JPH::EBodyType)(type));
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_PhysicsSystem_GetMaxBodies(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJph(in_physics_system)->GetMaxBodies();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_GetGravity(const JOLT_PhysicsSystem *in_physics_system, float out_gravity[3])
{
    storeVec3(out_gravity, toJph(in_physics_system)->GetGravity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_SetGravity(JOLT_PhysicsSystem *in_physics_system, const float in_gravity[3])
{
    toJph(in_physics_system)->SetGravity(loadVec3(in_gravity));
}
//--------------------------------------------------------------------------------------------------
 JOLT_BodyInterface *
JOLT_PhysicsSystem_GetBodyInterface(JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetBodyInterface());
}
 JOLT_BodyInterface *
JOLT_PhysicsSystem_GetBodyInterfaceNoLock(JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetBodyInterfaceNoLock());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_OptimizeBroadPhase(JOLT_PhysicsSystem *in_physics_system)
{
    toJph(in_physics_system)->OptimizeBroadPhase();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_AddStepListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener)
{
    assert(in_listener != nullptr);
    toJph(in_physics_system)->AddStepListener(static_cast<JPH::PhysicsStepListener *>(in_listener));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_RemoveStepListener(JOLT_PhysicsSystem *in_physics_system, void *in_listener)
{
    assert(in_listener != nullptr);
    toJph(in_physics_system)->RemoveStepListener(static_cast<JPH::PhysicsStepListener *>(in_listener));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_AddConstraint(JOLT_PhysicsSystem *in_physics_system, void *in_two_body_constraint)
{
    assert(in_two_body_constraint != nullptr);
    toJph(in_physics_system)->AddConstraint(static_cast<JPH::TwoBodyConstraint *>(in_two_body_constraint));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_PhysicsSystem_RemoveConstraint(JOLT_PhysicsSystem *in_physics_system, void *in_two_body_constraint)
{
    assert(in_two_body_constraint != nullptr);
    toJph(in_physics_system)->RemoveConstraint(static_cast<JPH::TwoBodyConstraint *>(in_two_body_constraint));
}


//--------------------------------------------------------------------------------------------------
 const JOLT_BodyLockInterface *
JOLT_PhysicsSystem_GetBodyLockInterface(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetBodyLockInterface());
}
 const JOLT_BodyLockInterface *
JOLT_PhysicsSystem_GetBodyLockInterfaceNoLock(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetBodyLockInterfaceNoLock());
}
//--------------------------------------------------------------------------------------------------
 const JOLT_NarrowPhaseQuery *
JOLT_PhysicsSystem_GetNarrowPhaseQuery(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetNarrowPhaseQuery());
}
 const JOLT_NarrowPhaseQuery *
JOLT_PhysicsSystem_GetNarrowPhaseQueryNoLock(const JOLT_PhysicsSystem *in_physics_system)
{
    return toJpc(&toJph(in_physics_system)->GetNarrowPhaseQueryNoLock());
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyLockInterface
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyLockInterface_LockRead(const JOLT_BodyLockInterface *in_lock_interface,
                               JOLT_BodyID in_body_id,
                               JOLT_BodyLockRead *out_lock)
{
    assert(out_lock != nullptr);
    ::new (out_lock) JPH::BodyLockRead(*toJph(in_lock_interface), toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyLockInterface_UnlockRead(const JOLT_BodyLockInterface *in_lock_interface,
                                 JOLT_BodyLockRead *io_lock)
{
    assert(io_lock != nullptr);
    assert(in_lock_interface != nullptr && in_lock_interface == io_lock->lock_interface);
    toJph(io_lock)->~BodyLockRead();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyLockInterface_LockWrite(const JOLT_BodyLockInterface *in_lock_interface,
                                JOLT_BodyID in_body_id,
                                JOLT_BodyLockWrite *out_lock)
{
    assert(out_lock != nullptr);
    ::new (out_lock) JPH::BodyLockWrite(*toJph(in_lock_interface), toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyLockInterface_UnlockWrite(const JOLT_BodyLockInterface *in_lock_interface,
                                  JOLT_BodyLockWrite *io_lock)
{
    assert(io_lock != nullptr);
    assert(in_lock_interface != nullptr && in_lock_interface == io_lock->lock_interface);
    toJph(io_lock)->~BodyLockWrite();
}

//--------------------------------------------------------------------------------------------------
//
// JOLT_NarrowPhaseQuery
//
//--------------------------------------------------------------------------------------------------
 bool
JOLT_NarrowPhaseQuery_CastRay(const JOLT_NarrowPhaseQuery *in_query,
                             const JOLT_RRayCast *in_ray,
                             JOLT_RayCastResult *io_hit,
                             const void *in_broad_phase_layer_filter,
                             const void *in_object_layer_filter,
                             const void *in_body_filter)
{
    assert(in_query && in_ray && io_hit);

    const JPH::BroadPhaseLayerFilter broad_phase_layer_filter{};
    const JPH::ObjectLayerFilter object_layer_filter{};
    const JPH::BodyFilter body_filter{};

    auto query = reinterpret_cast<const JPH::NarrowPhaseQuery *>(in_query);
    return query->CastRay(
        *reinterpret_cast<const JPH::RRayCast *>(in_ray),
        *reinterpret_cast<JPH::RayCastResult *>(io_hit),
        in_broad_phase_layer_filter ?
            *static_cast<const JPH::BroadPhaseLayerFilter *>(in_broad_phase_layer_filter) :
            broad_phase_layer_filter,
        in_object_layer_filter ?
            *static_cast<const JPH::ObjectLayerFilter *>(in_object_layer_filter) : object_layer_filter,
        in_body_filter ?
            *static_cast<const JPH::BodyFilter *>(in_body_filter) : body_filter);
}

//--------------------------------------------------------------------------------------------------
//
// JOLT_ShapeSettings
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_ShapeSettings_AddRef(JOLT_ShapeSettings *in_settings)
{
    toJph(in_settings)->AddRef();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ShapeSettings_Release(JOLT_ShapeSettings *in_settings)
{
    toJph(in_settings)->Release();
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_ShapeSettings_GetRefCount(const JOLT_ShapeSettings *in_settings)
{
    return toJph(in_settings)->GetRefCount();
}
//--------------------------------------------------------------------------------------------------
 JOLT_Shape *
JOLT_ShapeSettings_CreateShape(const JOLT_ShapeSettings *in_settings)
{
    const JPH::Result result = toJph(in_settings)->Create();
    if (result.HasError()) return nullptr;
    JPH::Shape *shape = const_cast<JPH::Shape *>(result.Get().GetPtr());
    shape->AddRef();
    return toJpc(shape);
}
//--------------------------------------------------------------------------------------------------
 uint64_t
JOLT_ShapeSettings_GetUserData(const JOLT_ShapeSettings *in_settings)
{
    return toJph(in_settings)->mUserData;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ShapeSettings_SetUserData(JOLT_ShapeSettings *in_settings, uint64_t in_user_data)
{
    toJph(in_settings)->mUserData = in_user_data;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConvexShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 const JOLT_PhysicsMaterial *
JOLT_ConvexShapeSettings_GetMaterial(const JOLT_ConvexShapeSettings *in_settings)
{
    // TODO: Increment ref count?
    return toJpc(toJph(in_settings)->mMaterial.GetPtr());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConvexShapeSettings_SetMaterial(JOLT_ConvexShapeSettings *in_settings,
                                    const JOLT_PhysicsMaterial *in_material)
{
    toJph(in_settings)->mMaterial = toJph(in_material);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_ConvexShapeSettings_GetDensity(const JOLT_ConvexShapeSettings *in_settings)
{
    return toJph(in_settings)->mDensity;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConvexShapeSettings_SetDensity(JOLT_ConvexShapeSettings *in_settings, float in_density)
{
    toJph(in_settings)->SetDensity(in_density);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_BoxShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_BoxShapeSettings *
JOLT_BoxShapeSettings_Create(const float in_half_extent[3])
{
    auto settings = new JPH::BoxShapeSettings(loadVec3(in_half_extent));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BoxShapeSettings_GetHalfExtent(const JOLT_BoxShapeSettings *in_settings, float out_half_extent[3])
{
    storeVec3(out_half_extent, toJph(in_settings)->mHalfExtent);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BoxShapeSettings_SetHalfExtent(JOLT_BoxShapeSettings *in_settings, const float in_half_extent[3])
{
    toJph(in_settings)->mHalfExtent = loadVec3(in_half_extent);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_BoxShapeSettings_GetConvexRadius(const JOLT_BoxShapeSettings *in_settings)
{
    return toJph(in_settings)->mConvexRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BoxShapeSettings_SetConvexRadius(JOLT_BoxShapeSettings *in_settings, float in_convex_radius)
{
    toJph(in_settings)->mConvexRadius = in_convex_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_SphereShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_SphereShapeSettings *
JOLT_SphereShapeSettings_Create(float in_radius)
{
    auto settings = new JPH::SphereShapeSettings(in_radius);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_SphereShapeSettings_GetRadius(const JOLT_SphereShapeSettings *in_settings)
{
    return toJph(in_settings)->mRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_SphereShapeSettings_SetRadius(JOLT_SphereShapeSettings *in_settings, float in_radius)
{
    toJph(in_settings)->mRadius = in_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_TriangleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_TriangleShapeSettings *
JOLT_TriangleShapeSettings_Create(const float in_v1[3], const float in_v2[3], const float in_v3[3])
{
    auto settings = new JPH::TriangleShapeSettings(loadVec3(in_v1), loadVec3(in_v2), loadVec3(in_v3));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TriangleShapeSettings_SetVertices(JOLT_TriangleShapeSettings *in_settings,
                                      const float in_v1[3],
                                      const float in_v2[3],
                                      const float in_v3[3])
{
    JPH::TriangleShapeSettings *settings = toJph(in_settings);
    settings->mV1 = loadVec3(in_v1);
    settings->mV2 = loadVec3(in_v2);
    settings->mV3 = loadVec3(in_v3);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TriangleShapeSettings_GetVertices(const JOLT_TriangleShapeSettings *in_settings,
                                      float out_v1[3],
                                      float out_v2[3],
                                      float out_v3[3])
{
    const JPH::TriangleShapeSettings *settings = toJph(in_settings);
    storeVec3(out_v1, settings->mV1);
    storeVec3(out_v2, settings->mV2);
    storeVec3(out_v3, settings->mV3);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_TriangleShapeSettings_GetConvexRadius(const JOLT_TriangleShapeSettings *in_settings)
{
    return toJph(in_settings)->mConvexRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TriangleShapeSettings_SetConvexRadius(JOLT_TriangleShapeSettings *in_settings, float in_convex_radius)
{
    toJph(in_settings)->mConvexRadius = in_convex_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CapsuleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CapsuleShapeSettings *
JOLT_CapsuleShapeSettings_Create(float in_half_height_of_cylinder, float in_radius)
{
    auto settings = new JPH::CapsuleShapeSettings(in_half_height_of_cylinder, in_radius);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_CapsuleShapeSettings_GetHalfHeight(const JOLT_CapsuleShapeSettings *in_settings)
{
    return toJph(in_settings)->mHalfHeightOfCylinder;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CapsuleShapeSettings_SetHalfHeight(JOLT_CapsuleShapeSettings *in_settings,
                                       float in_half_height_of_cylinder)
{
    toJph(in_settings)->mHalfHeightOfCylinder = in_half_height_of_cylinder;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_CapsuleShapeSettings_GetRadius(const JOLT_CapsuleShapeSettings *in_settings)
{
    return toJph(in_settings)->mRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CapsuleShapeSettings_SetRadius(JOLT_CapsuleShapeSettings *in_settings, float in_radius)
{
    toJph(in_settings)->mRadius = in_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_TaperedCapsuleShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_TaperedCapsuleShapeSettings *
JOLT_TaperedCapsuleShapeSettings_Create(float in_half_height, float in_top_radius, float in_bottom_radius)
{
    auto settings = new JPH::TaperedCapsuleShapeSettings(in_half_height, in_top_radius, in_bottom_radius);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_TaperedCapsuleShapeSettings_GetHalfHeight(const JOLT_TaperedCapsuleShapeSettings *in_settings)
{
    return toJph(in_settings)->mHalfHeightOfTaperedCylinder;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TaperedCapsuleShapeSettings_SetHalfHeight(JOLT_TaperedCapsuleShapeSettings *in_settings,
                                              float in_half_height)
{
    toJph(in_settings)->mHalfHeightOfTaperedCylinder = in_half_height;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_TaperedCapsuleShapeSettings_GetTopRadius(const JOLT_TaperedCapsuleShapeSettings *in_settings)
{
    return toJph(in_settings)->mTopRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TaperedCapsuleShapeSettings_SetTopRadius(JOLT_TaperedCapsuleShapeSettings *in_settings, float in_top_radius)
{
    toJph(in_settings)->mTopRadius = in_top_radius;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_TaperedCapsuleShapeSettings_GetBottomRadius(const JOLT_TaperedCapsuleShapeSettings *in_settings)
{
    return toJph(in_settings)->mBottomRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_TaperedCapsuleShapeSettings_SetBottomRadius(JOLT_TaperedCapsuleShapeSettings *in_settings,
                                                float in_bottom_radius)
{
    toJph(in_settings)->mBottomRadius = in_bottom_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CylinderShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CylinderShapeSettings *
JOLT_CylinderShapeSettings_Create(float in_half_height, float in_radius)
{
    auto settings = new JPH::CylinderShapeSettings(in_half_height, in_radius);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_CylinderShapeSettings_GetConvexRadius(const JOLT_CylinderShapeSettings *in_settings)
{
    return toJph(in_settings)->mConvexRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CylinderShapeSettings_SetConvexRadius(JOLT_CylinderShapeSettings *in_settings, float in_convex_radius)
{
    toJph(in_settings)->mConvexRadius = in_convex_radius;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_CylinderShapeSettings_GetHalfHeight(const JOLT_CylinderShapeSettings *in_settings)
{
    return toJph(in_settings)->mHalfHeight;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CylinderShapeSettings_SetHalfHeight(JOLT_CylinderShapeSettings *in_settings, float in_half_height)
{
    toJph(in_settings)->mHalfHeight = in_half_height;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_CylinderShapeSettings_GetRadius(const JOLT_CylinderShapeSettings *in_settings)
{
    return toJph(in_settings)->mRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CylinderShapeSettings_SetRadius(JOLT_CylinderShapeSettings *in_settings, float in_radius)
{
    toJph(in_settings)->mRadius = in_radius;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConvexHullShapeSettings (-> JOLT_ConvexShapeSettings -> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_ConvexHullShapeSettings *
JOLT_ConvexHullShapeSettings_Create(const void *in_vertices, uint32_t in_num_vertices, uint32_t in_vertex_size)
{
    assert(in_vertices && in_num_vertices >= 3);
    assert(in_vertex_size >= 3 * sizeof(float));

    JPH::Array<JPH::Vec3> points;
    points.reserve(in_num_vertices);

    for (uint32_t i = 0; i < in_num_vertices; ++i)
    {
        const uint8_t *base = static_cast<const uint8_t *>(in_vertices) + i * in_vertex_size;
        points.push_back(loadVec3(reinterpret_cast<const float *>(base)));
    }

    auto settings = new JPH::ConvexHullShapeSettings(points);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_ConvexHullShapeSettings_GetMaxConvexRadius(const JOLT_ConvexHullShapeSettings *in_settings)
{
    return toJph(in_settings)->mMaxConvexRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConvexHullShapeSettings_SetMaxConvexRadius(JOLT_ConvexHullShapeSettings *in_settings,
                                               float in_max_convex_radius)
{
    toJph(in_settings)->mMaxConvexRadius = in_max_convex_radius;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_ConvexHullShapeSettings_GetMaxErrorConvexRadius(const JOLT_ConvexHullShapeSettings *in_settings)
{
    return toJph(in_settings)->mMaxErrorConvexRadius;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConvexHullShapeSettings_SetMaxErrorConvexRadius(JOLT_ConvexHullShapeSettings *in_settings,
                                                    float in_max_err_convex_radius)
{
    toJph(in_settings)->mMaxErrorConvexRadius = in_max_err_convex_radius;
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_ConvexHullShapeSettings_GetHullTolerance(const JOLT_ConvexHullShapeSettings *in_settings)
{
    return toJph(in_settings)->mHullTolerance;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConvexHullShapeSettings_SetHullTolerance(JOLT_ConvexHullShapeSettings *in_settings,
                                             float in_hull_tolerance)
{
    toJph(in_settings)->mHullTolerance = in_hull_tolerance;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_HeightFieldShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_HeightFieldShapeSettings *
JOLT_HeightFieldShapeSettings_Create(const float *in_samples, uint32_t in_height_field_size)
{
    assert(in_samples != nullptr && in_height_field_size >= 2);
    auto settings = new JPH::HeightFieldShapeSettings(
        in_samples, JPH::Vec3(0,0,0), JPH::Vec3(1,1,1), in_height_field_size);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_GetOffset(const JOLT_HeightFieldShapeSettings *in_settings, float out_offset[3])
{
    storeVec3(out_offset, toJph(in_settings)->mOffset);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_SetOffset(JOLT_HeightFieldShapeSettings *in_settings, const float in_offset[3])
{
    toJph(in_settings)->mOffset = loadVec3(in_offset);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_GetScale(const JOLT_HeightFieldShapeSettings *in_settings, float out_scale[3])
{
    storeVec3(out_scale, toJph(in_settings)->mScale);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_SetScale(JOLT_HeightFieldShapeSettings *in_settings, const float in_scale[3])
{
    toJph(in_settings)->mScale = loadVec3(in_scale);
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_HeightFieldShapeSettings_GetBlockSize(const JOLT_HeightFieldShapeSettings *in_settings)
{
    return toJph(in_settings)->mBlockSize;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_SetBlockSize(JOLT_HeightFieldShapeSettings *in_settings, uint32_t in_block_size)
{
    toJph(in_settings)->mBlockSize = in_block_size;
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_HeightFieldShapeSettings_GetBitsPerSample(const JOLT_HeightFieldShapeSettings *in_settings)
{
    return toJph(in_settings)->mBitsPerSample;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_HeightFieldShapeSettings_SetBitsPerSample(JOLT_HeightFieldShapeSettings *in_settings, uint32_t in_num_bits)
{
    toJph(in_settings)->mBitsPerSample = in_num_bits;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_MeshShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_MeshShapeSettings *
JOLT_MeshShapeSettings_Create(const void *in_vertices,
                             uint32_t in_num_vertices,
                             uint32_t in_vertex_size,
                             const uint32_t *in_indices,
                             uint32_t in_num_indices)
{
    assert(in_vertices && in_indices);
    assert(in_num_vertices >= 3);
    assert(in_vertex_size >= 3 * sizeof(float));
    assert(in_num_indices >= 3 && in_num_indices % 3 == 0);

    JPH::VertexList vertices;
    vertices.reserve(in_num_vertices);

    for (uint32_t i = 0; i < in_num_vertices; ++i)
    {
        const float *base = reinterpret_cast<const float *>(
            static_cast<const uint8_t *>(in_vertices) + i * in_vertex_size);
        vertices.push_back(JPH::Float3(base[0], base[1], base[2]));
    }

    JPH::IndexedTriangleList triangles;
    triangles.reserve(in_num_indices / 3);

    for (uint32_t i = 0; i < in_num_indices / 3; ++i)
    {
        triangles.push_back(
            JPH::IndexedTriangle(in_indices[i * 3], in_indices[i * 3 + 1], in_indices[i * 3 + 2], 0));
    }

    auto settings = new JPH::MeshShapeSettings(vertices, triangles);
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_MeshShapeSettings_GetMaxTrianglesPerLeaf(const JOLT_MeshShapeSettings *in_settings)
{
    return toJph(in_settings)->mMaxTrianglesPerLeaf;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MeshShapeSettings_SetMaxTrianglesPerLeaf(JOLT_MeshShapeSettings *in_settings, uint32_t in_max_triangles)
{
    toJph(in_settings)->mMaxTrianglesPerLeaf = in_max_triangles;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MeshShapeSettings_Sanitize(JOLT_MeshShapeSettings *in_settings)
{
    toJph(in_settings)->Sanitize();
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_DecoratedShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_DecoratedShapeSettings *
JOLT_RotatedTranslatedShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                                          const JOLT_Real in_rotated[4],
                                          const JOLT_Real in_translated[3])
{
    auto settings = new JPH::RotatedTranslatedShapeSettings(loadRVec3(in_translated),
                                                            JPH::Quat(loadVec4(in_rotated)),
                                                            toJph(in_inner_shape_settings));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 JOLT_DecoratedShapeSettings *
JOLT_ScaledShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                               const JOLT_Real in_scale[3])
{
    auto settings = new JPH::ScaledShapeSettings(toJph(in_inner_shape_settings), loadRVec3(in_scale));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 JOLT_DecoratedShapeSettings *
JOLT_OffsetCenterOfMassShapeSettings_Create(const JOLT_ShapeSettings *in_inner_shape_settings,
                                           const JOLT_Real in_center_of_mass[3])
{
    auto settings = new JPH::OffsetCenterOfMassShapeSettings(loadRVec3(in_center_of_mass),
                                                             toJph(in_inner_shape_settings));
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CompoundShapeSettings (-> JOLT_ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_CompoundShapeSettings *
JOLT_StaticCompoundShapeSettings_Create()
{
    auto settings = new JPH::StaticCompoundShapeSettings();
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 JOLT_CompoundShapeSettings *
JOLT_MutableCompoundShapeSettings_Create()
{
    auto settings = new JPH::MutableCompoundShapeSettings();
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CompoundShapeSettings_AddShape(JOLT_CompoundShapeSettings *in_settings,
                                   const JOLT_Real in_position[3],
                                   const JOLT_Real in_rotation[4],
                                   const JOLT_ShapeSettings *in_shape,
                                   const uint32_t in_user_data)
{
    toJph(in_settings)->AddShape(loadRVec3(in_position),
                                 JPH::Quat(loadVec4(in_rotation)),
                                 toJph(in_shape),
                                 in_user_data);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_Shape
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_Shape_AddRef(JOLT_Shape *in_shape)
{
    toJph(in_shape)->AddRef();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Shape_Release(JOLT_Shape *in_shape)
{
    toJph(in_shape)->Release();
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_Shape_GetRefCount(const JOLT_Shape *in_shape)
{
    return toJph(in_shape)->GetRefCount();
}
//--------------------------------------------------------------------------------------------------
 JOLT_ShapeType
JOLT_Shape_GetType(const JOLT_Shape *in_shape)
{
    return toJpc(toJph(in_shape)->GetType());
}
//--------------------------------------------------------------------------------------------------
 JOLT_ShapeSubType
JOLT_Shape_GetSubType(const JOLT_Shape *in_shape)
{
    return toJpc(toJph(in_shape)->GetSubType());
}
//--------------------------------------------------------------------------------------------------
 uint64_t
JOLT_Shape_GetUserData(const JOLT_Shape *in_shape)
{
    return toJph(in_shape)->GetUserData();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Shape_SetUserData(JOLT_Shape *in_shape, uint64_t in_user_data)
{
    return toJph(in_shape)->SetUserData(in_user_data);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Shape_GetCenterOfMass(const JOLT_Shape *in_shape, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_shape)->GetCenterOfMass());
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_ConstraintSettings
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConstraintSettings_AddRef(JOLT_ConstraintSettings *in_settings)
{
    toJph(in_settings)->AddRef();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConstraintSettings_Release(JOLT_ConstraintSettings *in_settings)
{
    toJph(in_settings)->Release();
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_ConstraintSettings_GetRefCount(const JOLT_ConstraintSettings *in_settings)
{
    return toJph(in_settings)->GetRefCount();
}
//--------------------------------------------------------------------------------------------------
 uint64_t
JOLT_ConstraintSettings_GetUserData(const JOLT_ConstraintSettings *in_settings)
{
    return toJph(in_settings)->mUserData;
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_ConstraintSettings_SetUserData(JOLT_ConstraintSettings *in_settings, uint64_t in_user_data)
{
    toJph(in_settings)->mUserData = in_user_data;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_TwoBodyConstraintSettings (-> JOLT_ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_Constraint *
JOLT_TwoBodyConstraintSettings_CreateConstraint(const JOLT_TwoBodyConstraintSettings *in_settings,
                                               JOLT_Body *in_body1,
                                               JOLT_Body *in_body2)
{
    auto constraint = toJph(in_settings)->Create(*toJph(in_body1), *toJph(in_body2));
    if (constraint != nullptr) constraint->AddRef();
    return toJpc(constraint);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_FixedConstraintSettings (-> JOLT_TwoBodyConstraintSettings -> JOLT_ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
 JOLT_FixedConstraintSettings *
JOLT_FixedConstraintSettings_Create()
{
    auto settings = new JPH::FixedConstraintSettings();
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_FixedConstraintSettings_SetSpace(JOLT_FixedConstraintSettings *in_settings, JOLT_ConstraintSpace in_space)
{
    toJph(in_settings)->mSpace = toJph(in_space);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_FixedConstraintSettings_SetAutoDetectPoint(JOLT_FixedConstraintSettings *in_settings, bool in_enabled)
{
    toJph(in_settings)->mAutoDetectPoint = in_enabled;
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_Constraint
//
//--------------------------------------------------------------------------------------------------
 void
JOLT_Constraint_AddRef(JOLT_Constraint *in_shape)
{
    toJph(in_shape)->AddRef();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Constraint_Release(JOLT_Constraint *in_shape)
{
    toJph(in_shape)->Release();
}
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_Constraint_GetRefCount(const JOLT_Constraint *in_shape)
{
    return toJph(in_shape)->GetRefCount();
}
//--------------------------------------------------------------------------------------------------
 JOLT_ConstraintType
JOLT_Constraint_GetType(const JOLT_Constraint *in_shape)
{
    return toJpc(toJph(in_shape)->GetType());
}
//--------------------------------------------------------------------------------------------------
 JOLT_ConstraintSubType
JOLT_Constraint_GetSubType(const JOLT_Constraint *in_shape)
{
    return toJpc(toJph(in_shape)->GetSubType());
}
//--------------------------------------------------------------------------------------------------
 uint64_t
JOLT_Constraint_GetUserData(const JOLT_Constraint *in_shape)
{
    return toJph(in_shape)->GetUserData();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Constraint_SetUserData(JOLT_Constraint *in_shape, uint64_t in_user_data)
{
    return toJph(in_shape)->SetUserData(in_user_data);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyInterface
//
//--------------------------------------------------------------------------------------------------
/*
 JOLT_Body *
JOLT_BodyInterface_CreateBody(JOLT_BodyInterface *in_iface, const JOLT_BodyCreationSettings *in_settings)
{
    return toJpc(toJph(in_iface)->CreateBody(*toJph(in_settings)));
}
*/
//--------------------------------------------------------------------------------------------------
 JOLT_Body *
JOLT_BodyInterface_CreateBodyWithID(JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_BodyCreationSettings *in_settings)
{
    return toJpc(toJph(in_iface)->CreateBodyWithID(toJph(in_body_id), *toJph(in_settings)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_DestroyBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    toJph(in_iface)->DestroyBody(toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_Activation in_mode)
{
    toJph(in_iface)->AddBody(toJph(in_body_id), static_cast<JPH::EActivation>(in_mode));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_RemoveBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    toJph(in_iface)->RemoveBody(toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 JOLT_BodyID
JOLT_BodyInterface_CreateAndAddBody(JOLT_BodyInterface *in_iface,
                                   const JOLT_BodyCreationSettings *in_settings,
                                   JOLT_Activation in_mode)
{
    return toJpc(toJph(in_iface)->CreateAndAddBody(*toJph(in_settings),
        static_cast<JPH::EActivation>(in_mode)));
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_BodyInterface_IsAdded(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    return toJph(in_iface)->IsAdded(toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetLinearAndAngularVelocity(JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              const float in_linear_velocity[3],
                                              const float in_angular_velocity[3])
{
    toJph(in_iface)->SetLinearAndAngularVelocity(
        toJph(in_body_id), loadVec3(in_linear_velocity), loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetLinearAndAngularVelocity(const JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              float out_linear_velocity[3],
                                              float out_angular_velocity[3])
{
    JPH::Vec3 linear, angular;
    toJph(in_iface)->GetLinearAndAngularVelocity(toJph(in_body_id), linear, angular);
    storeVec3(out_linear_velocity, linear);
    storeVec3(out_angular_velocity, angular);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetLinearVelocity(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_velocity[3])
{
    toJph(in_iface)->SetLinearVelocity(toJph(in_body_id), loadVec3(in_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetLinearVelocity(const JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_iface)->GetLinearVelocity(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddLinearVelocity(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_velocity[3])
{
    toJph(in_iface)->AddLinearVelocity(toJph(in_body_id), loadVec3(in_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddLinearAndAngularVelocity(JOLT_BodyInterface *in_iface,
                                              JOLT_BodyID in_body_id,
                                              const float in_linear_velocity[3],
                                              const float in_angular_velocity[3])
{
    toJph(in_iface)->AddLinearAndAngularVelocity(
        toJph(in_body_id), loadVec3(in_linear_velocity), loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetAngularVelocity(JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     const float in_velocity[3])
{
    toJph(in_iface)->SetAngularVelocity(toJph(in_body_id), loadVec3(in_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetAngularVelocity(const JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_iface)->GetAngularVelocity(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetPointVelocity(const JOLT_BodyInterface *in_iface,
                                   JOLT_BodyID in_body_id,
                                   const JOLT_Real in_point[3],
                                   float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_iface)->GetPointVelocity(toJph(in_body_id), loadRVec3(in_point)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetPosition(const JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_iface)->GetPosition(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetPosition(JOLT_BodyInterface *in_iface,
                                          JOLT_BodyID in_body_id,
                                          const JOLT_Real in_position[3],
                                          JOLT_Activation in_activation)
{
    toJph(in_iface)->SetPosition(toJph(in_body_id), loadRVec3(in_position), static_cast<JPH::EActivation>(in_activation));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetCenterOfMassPosition(const JOLT_BodyInterface *in_iface,
                                          JOLT_BodyID in_body_id,
                                          JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_iface)->GetCenterOfMassPosition(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetRotation(JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              const JOLT_Real in_rotation[4],
                              JOLT_Activation in_activation)
{
    toJph(in_iface)->SetRotation(toJph(in_body_id), JPH::Quat(loadVec4(in_rotation)), static_cast<JPH::EActivation>(in_activation));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_GetRotation(const JOLT_BodyInterface *in_iface,
                              JOLT_BodyID in_body_id,
                              float out_rotation[4])
{
    storeVec4(out_rotation, toJph(in_iface)->GetRotation(toJph(in_body_id)).GetXYZW());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_ActivateBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    toJph(in_iface)->ActivateBody(toJph(in_body_id));
}

 void
JOLT_BodyInterface_DeactivateBody(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    toJph(in_iface)->DeactivateBody(toJph(in_body_id));
}

 bool
JOLT_BodyInterface_IsActive(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    return toJph(in_iface)->IsActive(toJph(in_body_id));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetPositionRotationAndVelocity(JOLT_BodyInterface *in_iface,
                                                 JOLT_BodyID in_body_id,
                                                 const JOLT_Real in_position[3],
                                                 const float in_rotation[4],
                                                 const float in_linear_velocity[3],
                                                 const float in_angular_velocity[3])
{
    toJph(in_iface)->SetPositionRotationAndVelocity(
        toJph(in_body_id),
        loadRVec3(in_position),
        JPH::Quat(loadVec4(in_rotation)),
        loadVec3(in_linear_velocity),
        loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddForce(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_force[3])
{
    toJph(in_iface)->AddForce(toJph(in_body_id), loadVec3(in_force));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddForceAtPosition(JOLT_BodyInterface *in_iface,
                                     JOLT_BodyID in_body_id,
                                     const float in_force[3],
                                     const JOLT_Real in_position[3])
{
    toJph(in_iface)->AddForce(toJph(in_body_id), loadVec3(in_force), loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddTorque(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_torque[3])
{
    toJph(in_iface)->AddTorque(toJph(in_body_id), loadVec3(in_torque));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddForceAndTorque(JOLT_BodyInterface *in_iface,
                                    JOLT_BodyID in_body_id,
                                    const float in_force[3],
                                    const float in_torque[3])
{
    toJph(in_iface)->AddForceAndTorque(toJph(in_body_id), loadVec3(in_force), loadVec3(in_torque));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddImpulse(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_impulse[3])
{
    toJph(in_iface)->AddImpulse(toJph(in_body_id), loadVec3(in_impulse));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddImpulseAtPosition(JOLT_BodyInterface *in_iface,
                                       JOLT_BodyID in_body_id,
                                       const float in_impulse[3],
                                       const JOLT_Real in_position[3])
{
    toJph(in_iface)->AddImpulse(toJph(in_body_id), loadVec3(in_impulse), loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_AddAngularImpulse(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, const float in_impulse[3])
{
    toJph(in_iface)->AddAngularImpulse(toJph(in_body_id), loadVec3(in_impulse));
}
//--------------------------------------------------------------------------------------------------
 JOLT_MotionType 
JOLT_BodyInterface_GetMotionType(const JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    return toJpc(toJph(in_iface)->GetMotionType(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetMotionType(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_MotionType in_motion_type, JOLT_Activation in_activation)
{
    toJph(in_iface)->SetMotionType(toJph(in_body_id), static_cast<JPH::EMotionType>(in_motion_type), static_cast<JPH::EActivation>(in_activation));
}
//--------------------------------------------------------------------------------------------------
 JOLT_ObjectLayer
JOLT_BodyInterface_GetObjectLayer(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id)
{
    return toJpc(toJph(in_iface)->GetObjectLayer(toJph(in_body_id)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_BodyInterface_SetObjectLayer(JOLT_BodyInterface *in_iface, JOLT_BodyID in_body_id, JOLT_ObjectLayer in_layer)
{
    toJph(in_iface)->SetObjectLayer(toJph(in_body_id), static_cast<JPH::ObjectLayer>(in_layer));
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_Body
//
//--------------------------------------------------------------------------------------------------
 JOLT_BodyID
JOLT_Body_GetID(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetID().GetIndexAndSequenceNumber();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsActive(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsActive();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsStatic(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsStatic();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsKinematic(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsKinematic();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsDynamic(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsDynamic();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_CanBeKinematicOrDynamic(const JOLT_Body *in_body)
{
    return toJph(in_body)->CanBeKinematicOrDynamic();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetIsSensor(JOLT_Body *in_body, bool in_is_sensor)
{
    toJph(in_body)->SetIsSensor(in_is_sensor);
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsSensor(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsSensor();
}
//--------------------------------------------------------------------------------------------------
 JOLT_MotionType
JOLT_Body_GetMotionType(const JOLT_Body *in_body)
{
    return toJpc(toJph(in_body)->GetMotionType());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetMotionType(JOLT_Body *in_body, JOLT_MotionType in_motion_type)
{
    toJph(in_body)->SetMotionType(static_cast<JPH::EMotionType>(in_motion_type));
}
//--------------------------------------------------------------------------------------------------
 JOLT_BroadPhaseLayer
JOLT_Body_GetBroadPhaseLayer(const JOLT_Body *in_body)
{
    return toJpc(toJph(in_body)->GetBroadPhaseLayer());
}
//--------------------------------------------------------------------------------------------------
 JOLT_ObjectLayer
JOLT_Body_GetObjectLayer(const JOLT_Body *in_body)
{
    return toJpc(toJph(in_body)->GetObjectLayer());
}
//--------------------------------------------------------------------------------------------------
 JOLT_CollisionGroup *
JOLT_Body_GetCollisionGroup(JOLT_Body *in_body)
{
    return toJpc(&toJph(in_body)->GetCollisionGroup());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetCollisionGroup(JOLT_Body *in_body, const JOLT_CollisionGroup *in_group)
{
    toJph(in_body)->SetCollisionGroup(*toJph(in_group));
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_GetAllowSleeping(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetAllowSleeping();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetAllowSleeping(JOLT_Body *in_body, bool in_allow)
{
    toJph(in_body)->SetAllowSleeping(in_allow);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_Body_GetFriction(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetFriction();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetFriction(JOLT_Body *in_body, float in_friction)
{
    toJph(in_body)->SetFriction(in_friction);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_Body_GetRestitution(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetRestitution();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetRestitution(JOLT_Body *in_body, float in_restitution)
{
    toJph(in_body)->SetRestitution(in_restitution);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetLinearVelocity(const JOLT_Body *in_body, float out_linear_velocity[3])
{
    storeVec3(out_linear_velocity, toJph(in_body)->GetLinearVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetLinearVelocity(JOLT_Body *in_body, const float in_linear_velocity[3])
{
    toJph(in_body)->SetLinearVelocity(loadVec3(in_linear_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetLinearVelocityClamped(JOLT_Body *in_body, const float in_linear_velocity[3])
{
    toJph(in_body)->SetLinearVelocityClamped(loadVec3(in_linear_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetAngularVelocity(const JOLT_Body *in_body, float out_angular_velocity[3])
{
    storeVec3(out_angular_velocity, toJph(in_body)->GetAngularVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetAngularVelocity(JOLT_Body *in_body, const float in_angular_velocity[3])
{
    toJph(in_body)->SetAngularVelocity(loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetAngularVelocityClamped(JOLT_Body *in_body, const float in_angular_velocity[3])
{
    toJph(in_body)->SetAngularVelocityClamped(loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetPointVelocityCOM(const JOLT_Body *in_body,
                             const float in_point_relative_to_com[3],
                             float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_body)->GetPointVelocityCOM(loadVec3(in_point_relative_to_com)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetPointVelocity(const JOLT_Body *in_body, const JOLT_Real in_point[3], float out_velocity[3])
{
    storeVec3(out_velocity, toJph(in_body)->GetPointVelocity(loadRVec3(in_point)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddForce(JOLT_Body *in_body, const float in_force[3])
{
    toJph(in_body)->AddForce(loadVec3(in_force));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddForceAtPosition(JOLT_Body *in_body, const float in_force[3], const JOLT_Real in_position[3])
{
    toJph(in_body)->AddForce(loadVec3(in_force), loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddTorque(JOLT_Body *in_body, const float in_torque[3])
{
    toJph(in_body)->AddTorque(loadVec3(in_torque));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetInverseInertia(const JOLT_Body *in_body, float out_inverse_inertia[16])
{
    storeMat44(out_inverse_inertia, toJph(in_body)->GetInverseInertia());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddImpulse(JOLT_Body *in_body, const float in_impulse[3])
{
    toJph(in_body)->AddImpulse(loadVec3(in_impulse));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddImpulseAtPosition(JOLT_Body *in_body, const float in_impulse[3], const JOLT_Real in_position[3])
{
    toJph(in_body)->AddImpulse(loadVec3(in_impulse), loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_AddAngularImpulse(JOLT_Body *in_body, const float in_angular_impulse[3])
{
    toJph(in_body)->AddAngularImpulse(loadVec3(in_angular_impulse));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_MoveKinematic(JOLT_Body *in_body,
                       const JOLT_Real in_target_position[3],
                       const float in_target_rotation[4],
                       float in_delta_time)
{
    toJph(in_body)->MoveKinematic(
        loadRVec3(in_target_position), JPH::Quat(loadVec4(in_target_rotation)), in_delta_time);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_ApplyBuoyancyImpulse(JOLT_Body *in_body,
                              const JOLT_Real in_surface_position[3],
                              const float in_surface_normal[3],
                              float in_buoyancy,
                              float in_linear_drag,
                              float in_angular_drag,
                              const float in_fluid_velocity[3],
                              const float in_gravity[3],
                              float in_delta_time)
{
    toJph(in_body)->ApplyBuoyancyImpulse(
        loadRVec3(in_surface_position),
        loadVec3(in_surface_normal),
        in_buoyancy,
        in_linear_drag,
        in_angular_drag,
        loadVec3(in_fluid_velocity),
        loadVec3(in_gravity),
        in_delta_time);
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsInBroadPhase(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsInBroadPhase();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_Body_IsCollisionCacheInvalid(const JOLT_Body *in_body)
{
    return toJph(in_body)->IsCollisionCacheInvalid();
}
//--------------------------------------------------------------------------------------------------
 const JOLT_Shape *
JOLT_Body_GetShape(const JOLT_Body *in_body)
{
    return toJpc(toJph(in_body)->GetShape());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetPosition(const JOLT_Body *in_body, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_body)->GetPosition());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetRotation(const JOLT_Body *in_body, float out_rotation[4])
{
    storeVec4(out_rotation, toJph(in_body)->GetRotation().GetXYZW());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetWorldTransform(const JOLT_Body *in_body, float out_rotation[9], JOLT_Real out_translation[3])
{
    const JPH::RMat44 m = toJph(in_body)->GetWorldTransform();
    storeVec3(&out_rotation[0], m.GetColumn3(0));
    storeVec3(&out_rotation[3], m.GetColumn3(1));
    storeVec3(&out_rotation[6], m.GetColumn3(2));
    storeRVec3(&out_translation[0], m.GetTranslation());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetCenterOfMassPosition(const JOLT_Body *in_body, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_body)->GetCenterOfMassPosition());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetCenterOfMassTransform(const JOLT_Body *in_body,
                                  float out_rotation[9],
                                  JOLT_Real out_translation[3])
{
    const JPH::RMat44 m = toJph(in_body)->GetCenterOfMassTransform();
    storeVec3(&out_rotation[0], m.GetColumn3(0));
    storeVec3(&out_rotation[3], m.GetColumn3(1));
    storeVec3(&out_rotation[6], m.GetColumn3(2));
    storeRVec3(&out_translation[0], m.GetTranslation());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetInverseCenterOfMassTransform(const JOLT_Body *in_body,
                                         float out_rotation[9],
                                         JOLT_Real out_translation[3])
{
    const JPH::RMat44 m = toJph(in_body)->GetInverseCenterOfMassTransform();
    storeVec3(&out_rotation[0], m.GetColumn3(0));
    storeVec3(&out_rotation[3], m.GetColumn3(1));
    storeVec3(&out_rotation[6], m.GetColumn3(2));
    storeRVec3(&out_translation[0], m.GetTranslation());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetWorldSpaceBounds(const JOLT_Body *in_body, float out_min[3], float out_max[3])
{
    const JPH::AABox& aabb = toJph(in_body)->GetWorldSpaceBounds();
    storeVec3(out_min, aabb.mMin);
    storeVec3(out_max, aabb.mMax);
}
//--------------------------------------------------------------------------------------------------
 JOLT_MotionProperties *
JOLT_Body_GetMotionProperties(JOLT_Body *in_body)
{
    return toJpc(toJph(in_body)->GetMotionProperties());
}
//--------------------------------------------------------------------------------------------------
 uint64_t
JOLT_Body_GetUserData(const JOLT_Body *in_body)
{
    return toJph(in_body)->GetUserData();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_SetUserData(JOLT_Body *in_body, uint64_t in_user_data)
{
    toJph(in_body)->SetUserData(in_user_data);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Body_GetWorldSpaceSurfaceNormal(const JOLT_Body *in_body,
                                    JOLT_SubShapeID in_sub_shape_id,
                                    const JOLT_Real in_position[3],
                                    float out_normal_vector[3])
{
    const JPH::Vec3 v = toJph(in_body)->GetWorldSpaceSurfaceNormal(
        *toJph(&in_sub_shape_id), loadRVec3(in_position));
    storeVec3(out_normal_vector, v);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_MotionProperties
//
//--------------------------------------------------------------------------------------------------
 JOLT_MotionQuality
JOLT_MotionProperties_GetMotionQuality(const JOLT_MotionProperties *in_properties)
{
    return toJpc(toJph(in_properties)->GetMotionQuality());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetLinearVelocity(const JOLT_MotionProperties *in_properties,
                                       float out_linear_velocity[3])
{
    storeVec3(out_linear_velocity, toJph(in_properties)->GetLinearVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetLinearVelocity(JOLT_MotionProperties *in_properties,
                                       const float in_linear_velocity[3])
{
    toJph(in_properties)->SetLinearVelocity(loadVec3(in_linear_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetLinearVelocityClamped(JOLT_MotionProperties *in_properties,
                                              const float in_linear_velocity[3])
{
    toJph(in_properties)->SetLinearVelocityClamped(loadVec3(in_linear_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetAngularVelocity(const JOLT_MotionProperties *in_properties,
                                        float out_angular_velocity[3])
{
    storeVec3(out_angular_velocity, toJph(in_properties)->GetAngularVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetAngularVelocity(JOLT_MotionProperties *in_properties,
                                        const float in_angular_velocity[3])
{
    toJph(in_properties)->SetAngularVelocity(loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetAngularVelocityClamped(JOLT_MotionProperties *in_properties,
                                               const float in_angular_velocity[3])
{
    toJph(in_properties)->SetAngularVelocityClamped(loadVec3(in_angular_velocity));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_MoveKinematic(JOLT_MotionProperties *in_properties,
                                   const float in_delta_position[3],
                                   const float in_delta_rotation[4],
                                   float in_delta_time)
{
    toJph(in_properties)->MoveKinematic(
        loadVec3(in_delta_position), JPH::Quat(loadVec4(in_delta_rotation)), in_delta_time);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_ClampLinearVelocity(JOLT_MotionProperties *in_properties)
{
    toJph(in_properties)->ClampLinearVelocity();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_ClampAngularVelocity(JOLT_MotionProperties *in_properties)
{
    toJph(in_properties)->ClampAngularVelocity();
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetLinearDamping(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetLinearDamping();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetLinearDamping(JOLT_MotionProperties *in_properties,
                                      float in_linear_damping)
{
    toJph(in_properties)->SetLinearDamping(in_linear_damping);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetAngularDamping(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetAngularDamping();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetAngularDamping(JOLT_MotionProperties *in_properties,
                                       float in_angular_damping)
{
    toJph(in_properties)->SetAngularDamping(in_angular_damping);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetGravityFactor(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetGravityFactor();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetGravityFactor(JOLT_MotionProperties *in_properties,
                                      float in_gravity_factor)
{
    toJph(in_properties)->SetGravityFactor(in_gravity_factor);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetMassProperties(JOLT_MotionProperties *in_properties,
                                      JOLT_AllowedDOFs dof, const JOLT_MassProperties *in_mass_properties)
{
    toJph(in_properties)->SetMassProperties((JPH::EAllowedDOFs)dof,*toJph(in_mass_properties));
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetInverseMass(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetInverseMass();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetInverseMass(JOLT_MotionProperties *in_properties, float in_inv_mass)
{
    toJph(in_properties)->SetInverseMass(in_inv_mass);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetInverseInertiaDiagonal(const JOLT_MotionProperties *in_properties,
                                               float out_inverse_inertia_diagonal[3])
{
    storeVec3(out_inverse_inertia_diagonal, toJph(in_properties)->GetInverseInertiaDiagonal());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetInertiaRotation(const JOLT_MotionProperties *in_properties,
                                        float out_inertia_rotation[4])
{
    storeVec4(out_inertia_rotation, toJph(in_properties)->GetInertiaRotation().GetXYZW());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetInverseInertia(JOLT_MotionProperties *in_properties,
                                       const float in_diagonal[3],
                                       const float in_rotation[4])
{
    toJph(in_properties)->SetInverseInertia(
        loadVec3(in_diagonal),
        JPH::Quat(loadVec4(in_rotation)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetLocalSpaceInverseInertia(const JOLT_MotionProperties *in_properties,
                                                 float out_matrix[16])
{
    storeMat44(out_matrix, toJph(in_properties)->GetLocalSpaceInverseInertia());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetInverseInertiaForRotation(const JOLT_MotionProperties *in_properties,
                                                  const float in_rotation_matrix[16],
                                                  float out_matrix[16])
{
    storeMat44(out_matrix, toJph(in_properties)->GetInverseInertiaForRotation(loadMat44(in_rotation_matrix)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_MultiplyWorldSpaceInverseInertiaByVector(const JOLT_MotionProperties *in_properties,
                                                              const float in_body_rotation[4],
                                                              const float in_vector[3],
                                                              float out_vector[3])
{
    const JPH::Vec3 v = toJph(in_properties)->MultiplyWorldSpaceInverseInertiaByVector(
        JPH::Quat(loadVec4(in_body_rotation)), loadVec3(in_vector));
    storeVec3(out_vector, v);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_GetPointVelocityCOM(const JOLT_MotionProperties *in_properties,
                                         const float in_point_relative_to_com[3],
                                         float out_point[3])
{
    storeVec3(out_point, toJph(in_properties)->GetPointVelocityCOM(loadVec3(in_point_relative_to_com)));
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetMaxLinearVelocity(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetMaxLinearVelocity();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetMaxLinearVelocity(JOLT_MotionProperties *in_properties,
                                          float in_max_linear_velocity)
{
    toJph(in_properties)->SetMaxLinearVelocity(in_max_linear_velocity);
}
//--------------------------------------------------------------------------------------------------
 float
JOLT_MotionProperties_GetMaxAngularVelocity(const JOLT_MotionProperties *in_properties)
{
    return toJph(in_properties)->GetMaxAngularVelocity();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_MotionProperties_SetMaxAngularVelocity(JOLT_MotionProperties *in_properties,
                                           float in_max_angular_velocity)
{
    toJph(in_properties)->SetMaxAngularVelocity(in_max_angular_velocity);
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_BodyID
//
//--------------------------------------------------------------------------------------------------
 uint32_t
JOLT_BodyID_GetIndex(JOLT_BodyID in_body_id)
{
    return JPH::BodyID(in_body_id).GetIndex();
}
//--------------------------------------------------------------------------------------------------
 uint8_t
JOLT_BodyID_GetSequenceNumber(JOLT_BodyID in_body_id)
{
    return JPH::BodyID(in_body_id).GetSequenceNumber();
}
//--------------------------------------------------------------------------------------------------
 bool
JOLT_BodyID_IsInvalid(JOLT_BodyID in_body_id)
{
    return JPH::BodyID(in_body_id).IsInvalid();
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterSettings
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterSettings *
JOLT_CharacterSettings_Create()
{
    auto settings = new JPH::CharacterSettings();
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterSettings_Release(JOLT_CharacterSettings *in_settings)
{
    toJph(in_settings)->Release();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterSettings_AddRef(JOLT_CharacterSettings *in_settings)
{
    toJph(in_settings)->AddRef();
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_Character
//
//--------------------------------------------------------------------------------------------------
 JOLT_Character *
JOLT_Character_Create(const JOLT_CharacterSettings *in_settings,
                     const JOLT_Real in_position[3],
                     const float in_rotation[4],
                     uint64_t in_user_data,
                     JOLT_PhysicsSystem *in_physics_system)
{
    auto character = new JPH::Character(toJph(in_settings),
                                        loadVec3(in_position),
                                        JPH::Quat(loadVec4(in_rotation)),
                                        in_user_data,
                                        toJph(in_physics_system));
    return toJpc(character);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_Destroy(JOLT_Character *in_character)
{
    delete toJph(in_character);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_AddToPhysicsSystem(JOLT_Character *in_character, JOLT_Activation in_activation, bool in_lock_bodies)
{
    toJph(in_character)->AddToPhysicsSystem(static_cast<JPH::EActivation>(in_activation), in_lock_bodies);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_RemoveFromPhysicsSystem(JOLT_Character *in_character, bool in_lock_bodies)
{
    toJph(in_character)->RemoveFromPhysicsSystem(in_lock_bodies);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_GetPosition(const JOLT_Character *in_character, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_character)->GetPosition());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_SetPosition(JOLT_Character *in_character, const JOLT_Real in_position[3])
{
    toJph(in_character)->SetPosition(loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_GetLinearVelocity(const JOLT_Character *in_character, float out_linear_velocity[3])
{
    storeVec3(out_linear_velocity, toJph(in_character)->GetLinearVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_Character_SetLinearVelocity(JOLT_Character *in_character, const float in_linear_velocity[3])
{
    toJph(in_character)->SetLinearVelocity(loadVec3(in_linear_velocity));
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterVirtualSettings
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterVirtualSettings *
JOLT_CharacterVirtualSettings_Create()
{
    auto settings = new JPH::CharacterVirtualSettings();
    settings->AddRef();
    return toJpc(settings);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtualSettings_Release(JOLT_CharacterVirtualSettings *in_settings)
{
    toJph(in_settings)->Release();
}
//--------------------------------------------------------------------------------------------------
//
// JOLT_CharacterVirtual
//
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterVirtual *
JOLT_CharacterVirtual_Create(const JOLT_CharacterVirtualSettings *in_settings,
                            const JOLT_Real in_position[3],
                            const float in_rotation[4],
                            JOLT_PhysicsSystem *in_physics_system)
{
    auto character = new JPH::CharacterVirtual(
        toJph(in_settings), loadVec3(in_position), JPH::Quat(loadVec4(in_rotation)), toJph(in_physics_system));
    return toJpc(character);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_Destroy(JOLT_CharacterVirtual *in_character)
{
    delete toJph(in_character);
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_Update(JOLT_CharacterVirtual *in_character,
                            float in_delta_time,
                            const float in_gravity[3],
                            const void *in_broad_phase_layer_filter,
                            const void *in_object_layer_filter,
                            const void *in_body_filter,
                            const void *in_shape_filter,
                            JOLT_TempAllocator *in_temp_allocator)
{
    const JPH::BroadPhaseLayerFilter broad_phase_layer_filter{};
    const JPH::ObjectLayerFilter object_layer_filter{};
    const JPH::BodyFilter body_filter{};
    const JPH::ShapeFilter shape_filter{};
    toJph(in_character)->Update(
        in_delta_time,
        loadVec3(in_gravity),
        in_broad_phase_layer_filter ?
        *static_cast<const JPH::BroadPhaseLayerFilter *>(in_broad_phase_layer_filter) : broad_phase_layer_filter,
        in_object_layer_filter ?
        *static_cast<const JPH::ObjectLayerFilter *>(in_object_layer_filter) : object_layer_filter,
        in_body_filter ? *static_cast<const JPH::BodyFilter *>(in_body_filter) : body_filter,
        in_shape_filter ? *static_cast<const JPH::ShapeFilter *>(in_shape_filter) : shape_filter,
        *reinterpret_cast<JPH::TempAllocator *>(in_temp_allocator));
}
//--------------------------------------------------------------------------------------------------
 JOLT_CharacterGroundState
JOLT_CharacterVirtual_GetGroundState(JOLT_CharacterVirtual *in_character)
{
    return toJpc(toJph(in_character)->GetGroundState());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_SetListener(JOLT_CharacterVirtual *in_character, void *in_listener)
{
    if (in_listener == nullptr)
    {
        toJph(in_character)->SetListener(nullptr);
        return;
    }
    toJph(in_character)->SetListener(static_cast<JPH::CharacterContactListener *>(in_listener));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_UpdateGroundVelocity(JOLT_CharacterVirtual *in_character)
{
    toJph(in_character)->UpdateGroundVelocity();
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_GetGroundVelocity(const JOLT_CharacterVirtual *in_character, float out_ground_velocity[3])
{
    storeVec3(out_ground_velocity, toJph(in_character)->GetGroundVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_GetPosition(const JOLT_CharacterVirtual *in_character, JOLT_Real out_position[3])
{
    storeRVec3(out_position, toJph(in_character)->GetPosition());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_SetPosition(JOLT_CharacterVirtual *in_character, const JOLT_Real in_position[3])
{
    toJph(in_character)->SetPosition(loadRVec3(in_position));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_GetRotation(const JOLT_CharacterVirtual *in_character, float out_rotation[4])
{
    storeVec4(out_rotation, toJph(in_character)->GetRotation().GetXYZW());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_SetRotation(JOLT_CharacterVirtual *in_character, const float in_rotation[4])
{
    toJph(in_character)->SetRotation(JPH::Quat(loadVec4(in_rotation)));
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_GetLinearVelocity(const JOLT_CharacterVirtual *in_character, float out_linear_velocity[3])
{
    storeVec3(out_linear_velocity, toJph(in_character)->GetLinearVelocity());
}
//--------------------------------------------------------------------------------------------------
 void
JOLT_CharacterVirtual_SetLinearVelocity(JOLT_CharacterVirtual *in_character, const float in_linear_velocity[3])
{
    toJph(in_character)->SetLinearVelocity(loadVec3(in_linear_velocity));
}
