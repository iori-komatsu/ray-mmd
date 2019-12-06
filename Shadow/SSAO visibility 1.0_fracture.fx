#define SSAO_VISIBILITY_ENABLE 1
#define SSAO_RECIEVER_ALPHA_ENABLE 1
#define SSAO_RECIEVER_ALPHA_MAP_ENABLE 1

static const float visibility = 1; // SSAO visibility

// {{{ fracture.fx
#define FRACTURE_ENABLED 1
// }}}

#include "../shader/SSAOVisibility.fxsub"